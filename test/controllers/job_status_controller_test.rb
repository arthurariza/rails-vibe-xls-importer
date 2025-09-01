# frozen_string_literal: true

require "test_helper"

class JobStatusControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def setup
    @user = users(:one)
    @import_template = ImportTemplate.create!(
      name: "Test Template",
      user: @user
    )
    @job_id = "test_job_123"
    sign_in @user
    
    # Setup cache for JobStatusService
    @original_cache_store = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end

  def teardown
    # Restore cache
    Rails.cache = @original_cache_store
  end

  test "should show job status page when job exists" do
    # Create job status in cache
    JobStatusService.update_status(@job_id, :processing, 
      started_at: Time.current,
      template_name: @import_template.name)

    get import_template_job_url(@import_template, @job_id)
    
    assert_response :success
    # Note: This will fail until routes are properly configured in task 4.6
  end

  test "should redirect when job status not found" do
    get import_template_job_url(@import_template, "nonexistent_job")
    
    # Should redirect to import template with error message
    # Note: This will fail until routes are properly configured in task 4.6
    assert_response :redirect
  end

  test "should return job status as JSON for API endpoint" do
    # Create job status in cache
    status_data = {
      status: :completed,
      started_at: Time.current,
      completed_at: Time.current,
      result_summary: "Successfully processed 10 records"
    }
    Rails.cache.write("job_status:#{@job_id}", status_data, expires_in: 24.hours)

    get job_status_api_path(@job_id), headers: { "Accept" => "application/json" }
    
    assert_response :success
    
    response_data = JSON.parse(response.body, symbolize_names: true)
    assert_equal :completed, response_data[:status].to_sym
    assert_equal "Successfully processed 10 records", response_data[:result_summary]
  end

  test "should return not_found status for nonexistent job in API" do
    get job_status_api_path("nonexistent_job"), headers: { "Accept" => "application/json" }
    
    assert_response :success
    
    response_data = JSON.parse(response.body, symbolize_names: true)
    assert_equal :not_found, response_data[:status].to_sym
  end

  test "should handle different job statuses in API response" do
    test_cases = [
      { status: :pending, created_at: Time.current },
      { status: :processing, started_at: Time.current, progress: "Processing row 50 of 100" },
      { status: :completed, completed_at: Time.current, result_summary: "Success", processed_count: 25 },
      { status: :failed, completed_at: Time.current, error_message: "Invalid file format" }
    ]

    test_cases.each_with_index do |status_data, index|
      job_id = "test_job_#{index}"
      Rails.cache.write("job_status:#{job_id}", status_data, expires_in: 24.hours)
      
      get job_status_api_path(job_id), headers: { "Accept" => "application/json" }
      
      assert_response :success
      
      response_data = JSON.parse(response.body, symbolize_names: true)
      assert_equal status_data[:status].to_s, response_data[:status]
      
      # Verify specific fields for each status
      case status_data[:status]
      when :pending
        assert_not_nil response_data[:created_at]
      when :processing
        assert_not_nil response_data[:started_at]
        assert_equal status_data[:progress], response_data[:progress] if status_data[:progress]
      when :completed
        assert_not_nil response_data[:completed_at]
        assert_equal status_data[:result_summary], response_data[:result_summary]
        assert_equal status_data[:processed_count], response_data[:processed_count]
      when :failed
        assert_not_nil response_data[:completed_at]
        assert_equal status_data[:error_message], response_data[:error_message]
      end
    end
  end

  test "should only allow access to own import templates" do
    other_user = users(:two)
    other_template = ImportTemplate.create!(
      name: "Other User Template",
      user: other_user
    )

    # Create job status for other user's template
    JobStatusService.update_status(@job_id, :processing, started_at: Time.current)

    get import_template_job_url(other_template, @job_id)
    
    # Should redirect with permission error
    # Note: This will fail until routes are properly configured in task 4.6
    assert_response :redirect
  end

  test "should handle cache errors gracefully in API" do
    # Mock Rails.cache to raise an error
    original_cache = Rails.cache
    error_cache = Object.new
    def error_cache.read(*_args)
      raise StandardError.new("Cache unavailable")
    end
    Rails.cache = error_cache

    begin
      get job_status_api_path(@job_id), headers: { "Accept" => "application/json" }
      
      # Should handle the error gracefully 
      assert_response :success
    ensure
      Rails.cache = original_cache
    end
  end

  test "should require authentication for job status pages" do
    sign_out @user
    
    JobStatusService.update_status(@job_id, :processing, started_at: Time.current)

    get import_template_job_url(@import_template, @job_id)
    
    # Should redirect to login
    assert_redirected_to new_user_session_url
  end

  test "API endpoint should work without authentication" do
    sign_out @user
    
    # Create job status
    status_data = { status: :processing, started_at: Time.current }
    Rails.cache.write("job_status:#{@job_id}", status_data, expires_in: 24.hours)

    get job_status_api_path(@job_id), headers: { "Accept" => "application/json" }
    
    # API should work without authentication (job_id acts as access token)
    assert_response :success
    
    response_data = JSON.parse(response.body, symbolize_names: true)
    assert_equal :processing, response_data[:status].to_sym
  end

  test "should handle missing import template gracefully" do
    JobStatusService.update_status(@job_id, :processing, started_at: Time.current)

    # Try to access a non-existent import template
    get import_template_job_url(999999, @job_id)
    
    # Should redirect with error when import template not found
    assert_redirected_to import_templates_path
    assert_equal "Import template not found.", flash[:alert]
  end

  # Task 3.10: Error handling tests

  test "should handle expired job status gracefully" do
    # Create an expired job status (simulate cache expiration)
    # Don't create any job status - it should return :not_found

    get import_template_job_url(@import_template, "expired_job_123")

    assert_redirected_to @import_template
    assert_equal "Job status not found. The job may have expired or never existed.", flash[:alert]
  end

  test "should handle failed jobs with error details" do
    # Create a failed job status
    JobStatusService.update_status(@job_id, :failed, 
      completed_at: Time.current,
      error_message: "Invalid file format - missing required headers")

    get import_template_job_url(@import_template, @job_id)

    assert_response :success
    # View should display the error message (tested in system tests)
  end

  test "should handle job status with processing errors" do
    # Create job status with partial success/errors
    JobStatusService.update_status(@job_id, :completed,
      completed_at: Time.current,
      result_summary: "Processed 8 of 10 records",
      processed_count: 8,
      error_count: 2,
      errors: ["Row 3: Missing required field 'email'", "Row 7: Invalid date format"])

    get import_template_job_url(@import_template, @job_id)

    assert_response :success
    # View should show both success and error information
  end

  test "should handle corrupted cache data in API" do
    # Mock JobStatusService to return corrupted data that causes an error
    JobStatusService.stub(:get_status, ->(_job_id) {
      # Simulate corrupted cache data causing an error
      raise JSON::ParserError.new("Invalid JSON data")
    }) do
      get job_status_api_path(@job_id), headers: { "Accept" => "application/json" }
    end

    assert_response :success
    
    response_data = JSON.parse(response.body, symbolize_names: true)
    # Should handle corrupted data gracefully
    assert_equal :error, response_data[:status].to_sym
    assert_equal "Unable to retrieve job status", response_data[:error]
  end

  test "should handle network timeout in status updates" do
    # Mock JobStatusService to simulate timeout
    JobStatusService.stub(:get_status, ->(_job_id) {
      raise StandardError.new("Cache connection timeout")
    }) do
      get job_status_api_path(@job_id), headers: { "Accept" => "application/json" }
    end

    # Should return error response
    assert_response :success
    
    response_data = JSON.parse(response.body, symbolize_names: true)
    # Should indicate an error occurred
    assert_equal :error, response_data[:status].to_sym
    assert_equal "Unable to retrieve job status", response_data[:error]
  end

  test "should handle job that never started" do
    # Create a job status that's stuck in pending state for a long time
    JobStatusService.update_status(@job_id, :pending, created_at: 2.hours.ago)

    get import_template_job_url(@import_template, @job_id)

    assert_response :success
    # View should indicate the job may be stuck
  end

  test "should reject access to other user's job status" do
    other_user = users(:two)
    other_template = ImportTemplate.create!(
      name: "Other User Template",
      user: other_user
    )

    # Create job status for other user's template
    other_job_id = "other_user_job_456"
    JobStatusService.update_status(other_job_id, :processing, started_at: Time.current)

    get import_template_job_url(other_template, other_job_id)

    # Should redirect due to authorization failure
    assert_redirected_to import_templates_path
    assert_equal "Import template not found.", flash[:alert]
  end

  test "should handle malformed job_id in API" do
    malformed_job_ids = ["null", "undefined", "<script>alert('xss')</script>", "very_long_job_id_that_might_cause_issues"]

    malformed_job_ids.each do |bad_job_id|
      # Skip empty strings as they cause route generation errors
      next if bad_job_id.blank?
      
      get job_status_api_path(bad_job_id), headers: { "Accept" => "application/json" }

      assert_response :success
      
      response_data = JSON.parse(response.body, symbolize_names: true)
      assert_equal :not_found, response_data[:status].to_sym
    end
  end

  test "should handle empty job_id gracefully" do
    # Test that empty job IDs are handled at the routing level
    # This would normally raise ActionController::UrlGenerationError
    assert_raises(ActionController::UrlGenerationError) do
      get job_status_api_path("")
    end
  end
end
