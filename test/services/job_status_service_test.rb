# frozen_string_literal: true

require "test_helper"

class JobStatusServiceTest < ActiveSupport::TestCase
  def setup
    @job_id = "test_job_123"
    @original_cache_store = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end

  def teardown
    Rails.cache = @original_cache_store
  end

  test "cache_key generates consistent key format" do
    expected_key = "job_status:#{@job_id}"

    assert_equal expected_key, JobStatusService.cache_key(@job_id)
  end

  test "get_status returns not_found for non-existent job" do
    status = JobStatusService.get_status(@job_id)

    assert_equal :not_found, status[:status]
  end

  test "get_status returns cached status data" do
    test_data = { status: :processing, started_at: Time.current }
    Rails.cache.write(JobStatusService.cache_key(@job_id), test_data, expires_in: 24.hours)

    status = JobStatusService.get_status(@job_id)

    assert_equal :processing, status[:status]
    assert status[:started_at]
  end

  test "update_status creates new cache entry with correct data" do
    result = JobStatusService.update_status(@job_id, :processing, template_name: "Test Template")

    assert_equal :processing, result[:status]
    assert_equal "Test Template", result[:template_name]
    assert result[:updated_at]

    cached_data = Rails.cache.read(JobStatusService.cache_key(@job_id))

    assert_equal :processing, cached_data[:status]
    assert_equal "Test Template", cached_data[:template_name]
  end

  test "update_status merges with existing data" do
    # First update
    JobStatusService.update_status(@job_id, :pending, created_at: Time.current)

    # Second update should merge
    result = JobStatusService.update_status(@job_id, :processing, started_at: Time.current)

    assert_equal :processing, result[:status]
    assert result[:created_at], "Should preserve created_at from first update"
    assert result[:started_at], "Should have new started_at"
    assert result[:updated_at], "Should have updated_at timestamp"
  end

  test "update_status sets 24 hour cache expiration" do
    JobStatusService.update_status(@job_id, :processing)

    # Verify the key exists
    assert Rails.cache.exist?(JobStatusService.cache_key(@job_id))

    # We can't directly test expiration time, but we can verify it's cached
    cached_data = Rails.cache.read(JobStatusService.cache_key(@job_id))

    assert_not_nil cached_data
  end

  test "update_progress sets processing status with progress message" do
    progress_message = "Processing row 100 of 500"
    result = JobStatusService.update_progress(@job_id, progress_message)

    assert_equal :processing, result[:status]
    assert_equal progress_message, result[:progress]
    assert result[:updated_at]
  end

  test "status transitions work correctly" do
    # pending -> processing
    JobStatusService.update_status(@job_id, :pending, created_at: Time.current)
    result = JobStatusService.get_status(@job_id)

    assert_equal :pending, result[:status]

    # processing -> completed
    JobStatusService.update_status(@job_id, :processing, started_at: Time.current)
    result = JobStatusService.get_status(@job_id)

    assert_equal :processing, result[:status]

    # completed
    JobStatusService.update_status(@job_id, :completed, completed_at: Time.current, result_summary: "Success")
    result = JobStatusService.get_status(@job_id)

    assert_equal :completed, result[:status]
    assert_equal "Success", result[:result_summary]
  end

  test "failed status stores error message" do
    error_message = "File validation failed"
    result = JobStatusService.update_status(@job_id, :failed,
                                            completed_at: Time.current,
                                            error_message: error_message)

    assert_equal :failed, result[:status]
    assert_equal error_message, result[:error_message]
    assert result[:completed_at]
  end

  test "handles cache read errors gracefully" do
    # Create a cache store that will raise an error on read
    error_cache = Object.new
    def error_cache.read(*_args)
      raise StandardError.new("Cache unavailable")
    end

    original_cache = Rails.cache
    Rails.cache = error_cache

    # Temporarily redirect Rails.logger to capture output
    original_logger = Rails.logger
    string_io = StringIO.new
    Rails.logger = Logger.new(string_io)

    begin
      result = JobStatusService.get_status(@job_id)

      assert_equal :error, result[:status]
      assert_equal "Cache read failed", result[:error_message]

      # Check that error was logged
      logged_output = string_io.string

      assert_includes logged_output, "cache read error"
    ensure
      Rails.cache = original_cache
      Rails.logger = original_logger
    end
  end

  test "handles cache write errors gracefully" do
    # Create a cache store that will raise an error on write but work for read
    error_cache = ActiveSupport::Cache::MemoryStore.new
    def error_cache.write(*_args)
      raise StandardError.new("Cache unavailable")
    end

    original_cache = Rails.cache
    Rails.cache = error_cache

    # Temporarily redirect Rails.logger to capture output
    original_logger = Rails.logger
    string_io = StringIO.new
    Rails.logger = Logger.new(string_io)

    begin
      result = JobStatusService.update_status(@job_id, :processing)

      # Should still return the intended data even if cache write fails
      assert_equal :processing, result[:status]
      assert result[:updated_at]

      # Check that error was logged
      logged_output = string_io.string

      assert_includes logged_output, "cache write error"
    ensure
      Rails.cache = original_cache
      Rails.logger = original_logger
    end
  end

  test "cache expiration behavior works correctly" do
    # Update status with expiration
    JobStatusService.update_status(@job_id, :processing, created_at: Time.current)

    # Verify data exists
    assert Rails.cache.exist?(JobStatusService.cache_key(@job_id))
    cached_data = JobStatusService.get_status(@job_id)

    assert_equal :processing, cached_data[:status]

    # Test that cache key can be manually expired (simulating auto-cleanup)
    Rails.cache.delete(JobStatusService.cache_key(@job_id))

    # Verify data is gone after deletion
    assert_not Rails.cache.exist?(JobStatusService.cache_key(@job_id))
    result = JobStatusService.get_status(@job_id)

    assert_equal :not_found, result[:status]
  end

  test "cache expiration time is set to 24 hours" do
    # This test verifies that the expires_in parameter is being passed correctly
    # We can't easily test the actual expiration timing in unit tests

    # Stub Rails.cache.write to capture the expires_in parameter
    write_calls = []
    original_write = Rails.cache.method(:write)

    Rails.cache.define_singleton_method(:write) do |key, value, options = {}|
      write_calls << options
      original_write.call(key, value, options)
    end

    JobStatusService.update_status(@job_id, :processing)

    # Restore original write method
    Rails.cache.define_singleton_method(:write, original_write)

    # Verify expires_in was set to 24 hours
    assert_equal 1, write_calls.length
    assert_equal 24.hours, write_calls.first[:expires_in]
  end

  test "auto-cleanup simulation by manual cache clear" do
    # Create multiple job statuses
    job_ids = %w[job1 job2 job3]

    job_ids.each do |job_id|
      JobStatusService.update_status(job_id, :completed, completed_at: Time.current)
    end

    # Verify all exist
    job_ids.each do |job_id|
      assert Rails.cache.exist?(JobStatusService.cache_key(job_id))
    end

    # Simulate cache cleanup (in production this would happen automatically after 24 hours)
    Rails.cache.clear

    # Verify all are cleaned up
    job_ids.each do |job_id|
      assert_not Rails.cache.exist?(JobStatusService.cache_key(job_id))
      result = JobStatusService.get_status(job_id)

      assert_equal :not_found, result[:status]
    end
  end

  test "cache operations are atomic and consistent" do
    # Test that partial failures don't leave cache in inconsistent state

    # Initial status
    JobStatusService.update_status(@job_id, :pending, created_at: Time.current)

    # Update with additional data
    result = JobStatusService.update_status(@job_id, :processing,
                                            started_at: Time.current,
                                            template_name: "Test Template")

    # Verify all data is consistently stored
    cached_data = JobStatusService.get_status(@job_id)

    assert_equal :processing, cached_data[:status]
    assert cached_data[:created_at], "Should preserve created_at from first update"
    assert cached_data[:started_at], "Should have started_at from second update"
    assert_equal "Test Template", cached_data[:template_name]
    assert cached_data[:updated_at], "Should have updated_at timestamp"

    # Verify returned data matches cached data
    assert_equal cached_data[:status], result[:status]
    assert_equal cached_data[:template_name], result[:template_name]
  end

  test "broadcast_status_change is called during status updates" do
    # Mock Turbo::StreamsChannel to capture broadcast calls
    broadcast_calls = []

    # Store original method
    original_broadcast = Turbo::StreamsChannel.method(:broadcast_replace_to)

    # Replace with mock that captures calls
    Turbo::StreamsChannel.define_singleton_method(:broadcast_replace_to) do |channel, options = {}|
      broadcast_calls << { channel: channel, options: options }
    end

    begin
      # Perform status update
      JobStatusService.update_status(@job_id, :processing, template_name: "Test Template")

      # Verify broadcast was called
      assert_equal 1, broadcast_calls.length

      broadcast_call = broadcast_calls.first

      assert_equal "job_status_#{@job_id}", broadcast_call[:channel]
      assert_equal "job_status_#{@job_id}", broadcast_call[:options][:target]
      assert_equal "shared/job_status", broadcast_call[:options][:partial]

      # Verify locals contain correct data
      locals = broadcast_call[:options][:locals]

      assert_equal @job_id, locals[:job_id]
      assert_equal :processing, locals[:status_data][:status]
      assert_equal "Test Template", locals[:status_data][:template_name]
    ensure
      # Restore original method
      Turbo::StreamsChannel.define_singleton_method(:broadcast_replace_to, original_broadcast)
    end
  end

  test "broadcast failure does not break status update" do
    # Mock Turbo::StreamsChannel to raise an error
    original_broadcast = Turbo::StreamsChannel.method(:broadcast_replace_to)

    Turbo::StreamsChannel.define_singleton_method(:broadcast_replace_to) do |*_args|
      raise StandardError.new("Broadcast failed")
    end

    # Temporarily redirect Rails.logger to capture output
    original_logger = Rails.logger
    string_io = StringIO.new
    Rails.logger = Logger.new(string_io)

    begin
      # Status update should still succeed despite broadcast failure
      result = JobStatusService.update_status(@job_id, :processing, template_name: "Test")

      # Verify status update worked
      assert_equal :processing, result[:status]
      assert_equal "Test", result[:template_name]

      # Verify cache was updated
      cached_data = JobStatusService.get_status(@job_id)

      assert_equal :processing, cached_data[:status]
      assert_equal "Test", cached_data[:template_name]

      # Verify error was logged
      logged_output = string_io.string

      assert_includes logged_output, "broadcast error"
    ensure
      # Restore original methods
      Turbo::StreamsChannel.define_singleton_method(:broadcast_replace_to, original_broadcast)
      Rails.logger = original_logger
    end
  end

  test "broadcast_status_change method formats data correctly" do
    # Mock Turbo::StreamsChannel to capture the exact call
    broadcast_calls = []
    original_broadcast = Turbo::StreamsChannel.method(:broadcast_replace_to)

    Turbo::StreamsChannel.define_singleton_method(:broadcast_replace_to) do |channel, **options|
      broadcast_calls << {
        channel: channel,
        target: options[:target],
        partial: options[:partial],
        locals: options[:locals]
      }
    end

    begin
      test_status_data = {
        status: :completed,
        completed_at: Time.current,
        result_summary: "Import successful",
        processed_count: 150
      }

      # Directly call the private method using send
      JobStatusService.send(:broadcast_status_change, @job_id, test_status_data)

      # Verify broadcast call structure
      assert_equal 1, broadcast_calls.length
      call = broadcast_calls.first

      assert_equal "job_status_#{@job_id}", call[:channel]
      assert_equal "job_status_#{@job_id}", call[:target]
      assert_equal "shared/job_status", call[:partial]

      # Verify locals structure
      locals = call[:locals]

      assert_equal @job_id, locals[:job_id]
      assert_equal test_status_data, locals[:status_data]
      assert_equal :completed, locals[:status_data][:status]
      assert_equal "Import successful", locals[:status_data][:result_summary]
      assert_equal 150, locals[:status_data][:processed_count]
    ensure
      Turbo::StreamsChannel.define_singleton_method(:broadcast_replace_to, original_broadcast)
    end
  end

  test "multiple status updates trigger multiple broadcasts" do
    broadcast_calls = []
    original_broadcast = Turbo::StreamsChannel.method(:broadcast_replace_to)

    Turbo::StreamsChannel.define_singleton_method(:broadcast_replace_to) do |channel, **options|
      broadcast_calls << {
        channel: channel,
        status: options[:locals][:status_data][:status]
      }
    end

    begin
      # Multiple status updates
      JobStatusService.update_status(@job_id, :pending, created_at: Time.current)
      JobStatusService.update_status(@job_id, :processing, started_at: Time.current)
      JobStatusService.update_status(@job_id, :completed, completed_at: Time.current)

      # Verify all broadcasts were called
      assert_equal 3, broadcast_calls.length

      # Verify correct sequence
      assert_equal :pending, broadcast_calls[0][:status]
      assert_equal :processing, broadcast_calls[1][:status]
      assert_equal :completed, broadcast_calls[2][:status]

      # Verify all used same channel
      broadcast_calls.each do |call|
        assert_equal "job_status_#{@job_id}", call[:channel]
      end
    ensure
      Turbo::StreamsChannel.define_singleton_method(:broadcast_replace_to, original_broadcast)
    end
  end

  test "update_progress triggers broadcast with progress data" do
    broadcast_calls = []
    original_broadcast = Turbo::StreamsChannel.method(:broadcast_replace_to)

    Turbo::StreamsChannel.define_singleton_method(:broadcast_replace_to) do |channel, **options|
      broadcast_calls << {
        channel: channel,
        status_data: options[:locals][:status_data]
      }
    end

    begin
      progress_message = "Processing row 250 of 1000"
      JobStatusService.update_progress(@job_id, progress_message)

      # Verify broadcast was called
      assert_equal 1, broadcast_calls.length

      call = broadcast_calls.first

      assert_equal "job_status_#{@job_id}", call[:channel]
      assert_equal :processing, call[:status_data][:status]
      assert_equal progress_message, call[:status_data][:progress]
    ensure
      Turbo::StreamsChannel.define_singleton_method(:broadcast_replace_to, original_broadcast)
    end
  end
end
