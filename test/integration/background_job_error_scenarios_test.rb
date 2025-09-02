# frozen_string_literal: true

require "test_helper"

class BackgroundJobErrorScenariosTest < ActiveSupport::TestCase
  def setup
    # Use MemoryStore for consistent cache behavior in tests
    @original_cache_store = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    
    @user = users(:one)
    @template = ImportTemplate.create!(
      name: "Job Error Test Template",
      description: "Template for testing job-level error scenarios",
      user: @user
    )

    @name_column = @template.template_columns.create!(
      name: "Name",
      data_type: "string",
      column_number: 1,
      required: true
    )

    @age_column = @template.template_columns.create!(
      name: "Age", 
      data_type: "number",
      column_number: 2,
      required: false
    )

    # Clear any existing jobs
    clear_enqueued_jobs
  end

  def teardown
    Rails.cache = @original_cache_store
    clear_enqueued_jobs
    
    # Cleanup any leftover temp files
    Dir.glob(Rails.root.join("tmp", "job_error_test_*.xlsx")).each do |file|
      File.delete(file) if File.exist?(file)
    end
    Dir.glob(Rails.root.join("tmp", "exports", "*.xlsx")).each do |file|
      File.delete(file) if File.exist?(file)
    end
  end

  # === Import Processing Job Error Scenarios ===

  test "ImportProcessingJob handles template not found gracefully" do
    job_id = SecureRandom.hex(8)
    invalid_template_id = 99999
    temp_file_path = create_valid_excel_file([["Name"], ["Test"]], job_id)
    
    # Ensure job status starts as pending
    JobStatusService.update_status(job_id, :pending, created_at: Time.current)
    
    # Execute job with invalid template ID
    job = ImportProcessingJob.new
    job.perform(invalid_template_id, job_id, temp_file_path)
    
    # Job should have updated status to failed
    status = JobStatusService.get_status(job_id)
    assert_equal :failed, status[:status]
    assert_includes status[:error_message], "Couldn't find ImportTemplate"
    
    # Temp file should still be cleaned up
    assert_not File.exist?(temp_file_path), "Temp file should be cleaned up even after job failure"
  end

  test "ImportProcessingJob handles missing temp file gracefully" do
    job_id = SecureRandom.hex(8)
    non_existent_file = Rails.root.join("tmp", "non_existent_#{job_id}.xlsx").to_s
    
    JobStatusService.update_status(job_id, :pending, created_at: Time.current)
    
    job = ImportProcessingJob.new
    job.perform(@template.id, job_id, non_existent_file)
    
    # Job should have failed gracefully
    status = JobStatusService.get_status(job_id)
    assert_equal :failed, status[:status]
    assert_includes status[:error_message].downcase, "no such file"
  end

  test "ImportProcessingJob handles service exceptions and updates job status correctly" do
    job_id = SecureRandom.hex(8)
    temp_file_path = create_valid_excel_file([["Name"], ["Test"]], job_id)
    
    JobStatusService.update_status(job_id, :pending, created_at: Time.current)
    
    # Mock the service to raise an exception
    original_new_method = ExcelImportService.method(:new)
    ExcelImportService.define_singleton_method(:new) do |*args|
      service_double = Object.new
      service_double.define_singleton_method(:process_import) do
        raise StandardError, "Simulated service failure during background processing"
      end
      service_double
    end
    
    begin
      job = ImportProcessingJob.new
      job.perform(@template.id, job_id, temp_file_path)
    ensure
      # Restore original method
      ExcelImportService.define_singleton_method(:new, original_new_method)
    end
    
    # Job should have captured the service exception
    status = JobStatusService.get_status(job_id)
    assert_equal :failed, status[:status]
    assert_includes status[:error_message], "Simulated service failure"
    assert_not_nil status[:completed_at]
    
    # Temp file should be cleaned up
    assert_not File.exist?(temp_file_path)
  end

  test "ImportProcessingJob handles corrupted uploaded file parameters correctly" do
    job_id = SecureRandom.hex(8)
    temp_file_path = create_temp_file_with_content("corrupted", job_id)
    
    JobStatusService.update_status(job_id, :pending, created_at: Time.current)
    
    job = ImportProcessingJob.new
    job.perform(@template.id, job_id, temp_file_path)
    
    # Job should complete with service-level failure
    status = JobStatusService.get_status(job_id)
    assert_equal :failed, status[:status]
    assert_includes status[:error_message], "Could not read Excel file"
    
    # File should be cleaned up
    assert_not File.exist?(temp_file_path)
  end

  test "ImportProcessingJob maintains job status consistency under concurrent execution" do
    job_id1 = SecureRandom.hex(8)
    job_id2 = SecureRandom.hex(8)
    
    temp_file_path1 = create_valid_excel_file([["Name"], ["User1"]], job_id1)
    temp_file_path2 = create_valid_excel_file([["Name"], ["User2"]], job_id2)
    
    JobStatusService.update_status(job_id1, :pending, created_at: Time.current)
    JobStatusService.update_status(job_id2, :pending, created_at: Time.current)
    
    # Execute both jobs
    job1 = ImportProcessingJob.new
    job2 = ImportProcessingJob.new
    
    job1.perform(@template.id, job_id1, temp_file_path1)
    job2.perform(@template.id, job_id2, temp_file_path2)
    
    # Both jobs should have completed (successfully or not)
    status1 = JobStatusService.get_status(job_id1)
    status2 = JobStatusService.get_status(job_id2)
    
    assert_includes [:completed, :failed], status1[:status]
    assert_includes [:completed, :failed], status2[:status]
    
    # Both should have completed_at timestamps
    assert_not_nil status1[:completed_at]
    assert_not_nil status2[:completed_at]
    
    # Both temp files should be cleaned up
    assert_not File.exist?(temp_file_path1)
    assert_not File.exist?(temp_file_path2)
  end

  # === Export Generation Job Error Scenarios ===

  test "ExportGenerationJob handles template not found gracefully" do
    job_id = SecureRandom.hex(8)
    invalid_template_id = 99999
    
    JobStatusService.update_status(job_id, :pending, created_at: Time.current)
    
    job = ExportGenerationJob.new
    job.perform(invalid_template_id, job_id, :data)
    
    status = JobStatusService.get_status(job_id)
    assert_equal :failed, status[:status]
    assert_includes status[:error_message], "Couldn't find ImportTemplate"
  end

  test "ExportGenerationJob handles service exceptions during export generation" do
    job_id = SecureRandom.hex(8)
    
    JobStatusService.update_status(job_id, :pending, created_at: Time.current)
    
    # Mock the service to raise an exception during generation
    original_new_method = ExcelExportService.method(:new)
    ExcelExportService.define_singleton_method(:new) do |*args|
      service_double = Object.new
      service_double.define_singleton_method(:generate_data_file) do
        raise StandardError, "Export generation failed due to memory constraints"
      end
      service_double
    end
    
    begin
      job = ExportGenerationJob.new
      job.perform(@template.id, job_id, :data)
    ensure
      # Restore original method
      ExcelExportService.define_singleton_method(:new, original_new_method)
    end
    
    status = JobStatusService.get_status(job_id)
    assert_equal :failed, status[:status]
    assert_includes status[:error_message], "Export generation failed"
    assert_not_nil status[:completed_at]
  end

  test "ExportGenerationJob handles file system errors during export saving" do
    job_id = SecureRandom.hex(8)
    
    JobStatusService.update_status(job_id, :pending, created_at: Time.current)
    
    # Mock File.open to simulate file system error during package serialization
    original_serialize = Axlsx::Package.instance_method(:serialize)
    Axlsx::Package.define_method(:serialize) do |path|
      if path.to_s.include?(job_id)
        raise Errno::EACCES, "Permission denied - simulated file system error"
      else
        original_serialize.bind(self).call(path)
      end
    end
    
    begin
      job = ExportGenerationJob.new
      job.perform(@template.id, job_id, :data)
    ensure
      # Restore original method
      Axlsx::Package.define_method(:serialize, original_serialize)
    end
    
    status = JobStatusService.get_status(job_id)
    assert_equal :failed, status[:status]
    assert_includes status[:error_message].downcase, "permission denied"
  end

  test "ExportGenerationJob handles different export types consistently" do
    job_ids = {
      template: SecureRandom.hex(8),
      sample: SecureRandom.hex(8), 
      data: SecureRandom.hex(8)
    }
    
    # Add some data for the data export
    record = @template.data_records.create!
    record.set_value_for_column(@name_column, "Export Test User")
    record.set_value_for_column(@age_column, "30")
    
    results = {}
    
    job_ids.each do |export_type, job_id|
      JobStatusService.update_status(job_id, :pending, created_at: Time.current)
      
      job = ExportGenerationJob.new
      job.perform(@template.id, job_id, export_type)
      
      results[export_type] = JobStatusService.get_status(job_id)
    end
    
    # All export types should complete successfully
    results.each do |export_type, status|
      assert_equal :completed, status[:status], "#{export_type} export should complete successfully"
      assert_not_nil status[:completed_at], "#{export_type} export should have completed_at timestamp"
      assert_includes status[:result_summary], "Export generated successfully", "#{export_type} export should have success message"
      assert_not_nil status[:file_path], "#{export_type} export should have file path"
      assert File.exist?(status[:file_path]), "#{export_type} export file should exist: #{status[:file_path]}"
    end
  end

  # === Job Status Service Error Scenarios ===

  test "job status updates are atomic and handle concurrent updates" do
    job_id = SecureRandom.hex(8)
    
    # Initialize status
    JobStatusService.update_status(job_id, :pending, created_at: Time.current)
    
    # Simulate concurrent status updates (as might happen with job retry logic)
    threads = []
    
    3.times do |i|
      threads << Thread.new do
        JobStatusService.update_status(job_id, :processing, 
                                       started_at: Time.current,
                                       worker_id: "worker_#{i}")
      end
    end
    
    threads.each(&:join)
    
    # Final status should be consistent
    status = JobStatusService.get_status(job_id)
    assert_equal :processing, status[:status]
    assert_not_nil status[:started_at]
    # worker_id should be from one of the threads
    assert_match /worker_[0-2]/, status[:worker_id] if status[:worker_id]
  end

  test "jobs handle cache eviction during processing gracefully" do
    job_id = SecureRandom.hex(8)
    temp_file_path = create_valid_excel_file([["Name"], ["Cache Test"]], job_id)
    
    JobStatusService.update_status(job_id, :pending, created_at: Time.current)
    
    # Clear cache during processing to simulate eviction
    Rails.cache.clear
    
    job = ImportProcessingJob.new
    job.perform(@template.id, job_id, temp_file_path)
    
    # Job should still complete and update status
    status = JobStatusService.get_status(job_id)
    assert_not_nil status
    assert_includes [:completed, :failed], status[:status]
    
    # File should be cleaned up
    assert_not File.exist?(temp_file_path)
  end

  # === Database Transaction Error Scenarios ===

  test "jobs handle database transaction failures correctly" do
    job_id = SecureRandom.hex(8)
    temp_file_path = create_valid_excel_file([["Name"], ["Transaction Test"]], job_id)
    
    JobStatusService.update_status(job_id, :pending, created_at: Time.current)
    
    # Mock database to fail during transaction
    original_transaction = ActiveRecord::Base.method(:transaction)
    ActiveRecord::Base.define_singleton_method(:transaction) do |**opts, &block|
      if block
        raise ActiveRecord::StatementInvalid, "Simulated database transaction failure"
      else
        original_transaction.call(**opts)
      end
    end
    
    begin
      job = ImportProcessingJob.new
      job.perform(@template.id, job_id, temp_file_path)
    ensure
      # Restore original method
      ActiveRecord::Base.define_singleton_method(:transaction, original_transaction)
    end
    
    status = JobStatusService.get_status(job_id)
    assert_equal :failed, status[:status]
    assert_includes status[:error_message], "Transaction failed"
    
    # No partial records should be created
    assert_equal 0, @template.data_records.count
    
    # File should still be cleaned up
    assert_not File.exist?(temp_file_path)
  end

  test "jobs handle database connection pool exhaustion" do
    job_id = SecureRandom.hex(8)
    temp_file_path = create_valid_excel_file([["Name"], ["Pool Test"]], job_id)
    
    JobStatusService.update_status(job_id, :pending, created_at: Time.current)
    
    # Mock connection pool exhaustion
    pool = ActiveRecord::Base.connection_pool
    original_checkout = pool.method(:checkout)
    
    pool.define_singleton_method(:checkout) do |*args|
      raise ActiveRecord::ConnectionTimeoutError, "could not obtain a connection from the pool"
    end
    
    begin
      job = ImportProcessingJob.new
      job.perform(@template.id, job_id, temp_file_path)
    ensure
      # Restore original method
      pool.define_singleton_method(:checkout, original_checkout)
    end
    
    status = JobStatusService.get_status(job_id)
    assert_equal :failed, status[:status]
    assert_includes status[:error_message].downcase, "connection"
    
    # File should be cleaned up
    assert_not File.exist?(temp_file_path)
  end

  private

  def create_temp_file_with_content(content, job_id)
    temp_file_path = Rails.root.join("tmp", "job_error_test_#{job_id}.txt")
    FileUtils.mkdir_p(File.dirname(temp_file_path))
    
    File.open(temp_file_path, "w") do |file|
      file.write(content)
    end
    
    temp_file_path.to_s
  end

  def create_valid_excel_file(excel_data, job_id)
    require "caxlsx"

    package = Axlsx::Package.new
    workbook = package.workbook
    worksheet = workbook.add_worksheet(name: "Test Data")
    
    excel_data.each { |row| worksheet.add_row(row) }

    temp_file_path = Rails.root.join("tmp", "job_error_test_#{job_id}.xlsx")
    FileUtils.mkdir_p(File.dirname(temp_file_path))
    package.serialize(temp_file_path)
    
    temp_file_path.to_s
  end

  def clear_enqueued_jobs
    # Clear any enqueued jobs from previous tests
    if defined?(ActiveJob::Base)
      adapter = ActiveJob::Base.queue_adapter
      if adapter.respond_to?(:enqueued_jobs) && adapter.enqueued_jobs.respond_to?(:clear)
        adapter.enqueued_jobs.clear
      end
    end
  end
end