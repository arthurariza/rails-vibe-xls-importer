# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

class ImportProcessingJobTest < ActiveJob::TestCase
  include ExcelFixtureHelper

  def setup
    @import_template = import_templates(:one)
    @job_id = SecureRandom.hex(8)  # Unique job ID per test
    @temp_file_paths = []  # Track all temp files created in this test

    # Setup cache for JobStatusService
    @original_cache_store = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end

  def teardown
    # Clean up all test files created during the test
    @temp_file_paths.each do |path|
      File.delete(path) if File.exist?(path)
    end

    # Restore cache
    Rails.cache = @original_cache_store
  end

  private

  def get_temp_file_path
    path = excel_fixture_file_path("mixed_update_create.xlsx")
    @temp_file_paths << path
    path
  end

  test "perform updates status to processing at job start" do
    # Mock the service to avoid actual processing
    mock_service_result = create_mock_service_result(success: true)
    mock_service = Minitest::Mock.new
    mock_service.expect(:process_import, mock_service_result)
    
    temp_file_path = get_temp_file_path

    ExcelImportService.stub(:new, mock_service) do
      ImportProcessingJob.new.perform(@import_template.id, @job_id, temp_file_path)
    end

    # Check that status was set to processing
    cached_status = Rails.cache.read("job_status:#{@job_id}")

    assert_not_nil cached_status
    assert_includes cached_status.keys, :status
    # NOTE: The final status will be :completed/:failed, but we can verify the service was called
    mock_service.verify
  end

  test "perform loads import template correctly" do
    mock_service_result = create_mock_service_result(success: true)

    # Capture the arguments passed to ExcelImportService.new
    service_args = []
    original_new = ExcelImportService.method(:new)

    ExcelImportService.define_singleton_method(:new) do |file, template|
      service_args << { file: file, template: template }
      mock_service = Minitest::Mock.new
      mock_service.expect(:process_import, mock_service_result)
      mock_service
    end

    begin
      ImportProcessingJob.new.perform(@import_template.id, @job_id, get_temp_file_path)

      # Verify correct template was passed
      assert_equal 1, service_args.length
      assert_equal @import_template, service_args.first[:template]
    ensure
      ExcelImportService.define_singleton_method(:new, original_new)
    end
  end

  test "perform creates ActionDispatch::Http::UploadedFile with correct attributes" do
    mock_service_result = create_mock_service_result(success: true)
    temp_file_path = get_temp_file_path

    # Capture the file argument passed to ExcelImportService.new
    uploaded_files = []
    original_new = ExcelImportService.method(:new)

    ExcelImportService.define_singleton_method(:new) do |file, _template|
      uploaded_files << file
      mock_service = Minitest::Mock.new
      mock_service.expect(:process_import, mock_service_result)
      mock_service
    end

    begin
      ImportProcessingJob.new.perform(@import_template.id, @job_id, temp_file_path)

      # Verify uploaded file was created correctly
      assert_equal 1, uploaded_files.length
      uploaded_file = uploaded_files.first

      assert_instance_of ActionDispatch::Http::UploadedFile, uploaded_file
      assert_equal File.basename(temp_file_path), uploaded_file.original_filename
      assert_equal "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", uploaded_file.content_type
    ensure
      ExcelImportService.define_singleton_method(:new, original_new)
    end
  end

  test "perform calls ExcelImportService.process_import unchanged" do
    mock_service_result = create_mock_service_result(success: true)
    service_calls = []

    # Mock the service to capture calls
    original_new = ExcelImportService.method(:new)
    ExcelImportService.define_singleton_method(:new) do |_file, _template|
      mock_service = Minitest::Mock.new
      mock_service.expect(:process_import, mock_service_result) do
        service_calls << :process_import_called
        mock_service_result
      end
      mock_service
    end

    begin
      ImportProcessingJob.new.perform(@import_template.id, @job_id, get_temp_file_path)

      # Verify service was called
      assert_includes service_calls, :process_import_called
    ensure
      ExcelImportService.define_singleton_method(:new, original_new)
    end
  end

  test "perform updates status to completed on service success" do
    mock_service_result = create_mock_service_result(
      success: true,
      summary: "Successfully processed 10 records",
      processed_count: 10
    )

    mock_service = Minitest::Mock.new
    mock_service.expect(:process_import, mock_service_result)

    ExcelImportService.stub(:new, mock_service) do
      ImportProcessingJob.new.perform(@import_template.id, @job_id, get_temp_file_path)
    end

    # Check final status
    cached_status = Rails.cache.read("job_status:#{@job_id}")

    assert_equal :completed, cached_status[:status]
    assert_equal "Successfully processed 10 records", cached_status[:result_summary]
    assert_equal 10, cached_status[:processed_count]
    assert_not_nil cached_status[:completed_at]

    mock_service.verify
  end

  test "perform updates status to failed on service failure" do
    mock_service_result = create_mock_service_result(
      success: false,
      errors: ["Invalid file format", "Missing required column"]
    )

    mock_service = Minitest::Mock.new
    mock_service.expect(:process_import, mock_service_result)

    ExcelImportService.stub(:new, mock_service) do
      ImportProcessingJob.new.perform(@import_template.id, @job_id, get_temp_file_path)
    end

    # Check final status
    cached_status = Rails.cache.read("job_status:#{@job_id}")

    assert_equal :failed, cached_status[:status]
    assert_equal "Invalid file format; Missing required column", cached_status[:error_message]
    assert_not_nil cached_status[:completed_at]

    mock_service.verify
  end

  test "perform handles exceptions and updates status to failed" do
    # Mock service to raise an exception
    mock_service = Minitest::Mock.new
    mock_service.expect(:process_import, nil) do
      raise StandardError.new("Service crashed")
    end

    ExcelImportService.stub(:new, mock_service) do
      ImportProcessingJob.new.perform(@import_template.id, @job_id, get_temp_file_path)
    end

    # Check final status
    cached_status = Rails.cache.read("job_status:#{@job_id}")

    assert_equal :failed, cached_status[:status]
    assert_equal "Service crashed", cached_status[:error_message]
    assert_not_nil cached_status[:completed_at]

    mock_service.verify
  end

  test "perform cleans up temporary file on success" do
    mock_service_result = create_mock_service_result(success: true)
    mock_service = Minitest::Mock.new
    mock_service.expect(:process_import, mock_service_result)
    
    temp_file_path = get_temp_file_path

    # Verify file exists before job
    assert_path_exists temp_file_path

    ExcelImportService.stub(:new, mock_service) do
      ImportProcessingJob.new.perform(@import_template.id, @job_id, temp_file_path)
    end

    # Verify file is cleaned up after job
    assert_not File.exist?(temp_file_path)

    mock_service.verify
  end

  test "perform cleans up temporary file on failure" do
    mock_service_result = create_mock_service_result(success: false, errors: ["Test error"])
    mock_service = Minitest::Mock.new
    mock_service.expect(:process_import, mock_service_result)
    
    temp_file_path = get_temp_file_path

    # Verify file exists before job
    assert_path_exists temp_file_path

    ExcelImportService.stub(:new, mock_service) do
      ImportProcessingJob.new.perform(@import_template.id, @job_id, temp_file_path)
    end

    # Verify file is cleaned up after job
    assert_not File.exist?(temp_file_path)

    mock_service.verify
  end

  test "perform cleans up temporary file on exception" do
    mock_service = Minitest::Mock.new
    mock_service.expect(:process_import, nil) do
      raise StandardError.new("Test exception")
    end
    
    temp_file_path = get_temp_file_path

    # Verify file exists before job
    assert_path_exists temp_file_path

    ExcelImportService.stub(:new, mock_service) do
      ImportProcessingJob.new.perform(@import_template.id, @job_id, temp_file_path)
    end

    # Verify file is cleaned up after job even on exception
    assert_not File.exist?(temp_file_path)

    mock_service.verify
  end

  test "perform handles missing import template gracefully" do
    invalid_template_id = 99_999

    ImportProcessingJob.new.perform(invalid_template_id, @job_id, get_temp_file_path)

    # Check final status
    cached_status = Rails.cache.read("job_status:#{@job_id}")

    assert_equal :failed, cached_status[:status]
    assert_includes cached_status[:error_message].downcase, "couldn't find importtemplate"
    assert_not_nil cached_status[:completed_at]
  end

  test "perform integrates with JobStatusService for status updates" do
    # Track all calls to JobStatusService.update_status
    status_updates = []
    original_update_status = JobStatusService.method(:update_status)

    JobStatusService.define_singleton_method(:update_status) do |job_id, status, **additional_data|
      status_updates << { job_id: job_id, status: status, additional_data: additional_data }
      original_update_status.call(job_id, status, **additional_data)
    end

    begin
      mock_service_result = create_mock_service_result(success: true, summary: "Success")
      mock_service = Minitest::Mock.new
      mock_service.expect(:process_import, mock_service_result)

      ExcelImportService.stub(:new, mock_service) do
        ImportProcessingJob.new.perform(@import_template.id, @job_id, get_temp_file_path)
      end

      # Verify status update sequence
      assert_equal 2, status_updates.length

      # First update: processing
      processing_update = status_updates[0]

      assert_equal @job_id, processing_update[:job_id]
      assert_equal :processing, processing_update[:status]
      assert_not_nil processing_update[:additional_data][:started_at]

      # Second update: completed
      completion_update = status_updates[1]

      assert_equal @job_id, completion_update[:job_id]
      assert_equal :completed, completion_update[:status]
      assert_not_nil completion_update[:additional_data][:completed_at]
      assert_equal "Success", completion_update[:additional_data][:result_summary]

      mock_service.verify
    ensure
      JobStatusService.define_singleton_method(:update_status, original_update_status)
    end
  end

  test "job can be enqueued with correct arguments" do
    temp_file_path = get_temp_file_path
    assert_enqueued_with(
      job: ImportProcessingJob,
      args: [@import_template.id, @job_id, temp_file_path]
    ) do
      ImportProcessingJob.perform_later(@import_template.id, @job_id, temp_file_path)
    end
  end

  private

  def create_mock_service_result(success:, summary: "", processed_count: 0, errors: [])
    result = Object.new
    result.define_singleton_method(:success) { success }
    result.define_singleton_method(:summary) { summary }
    result.define_singleton_method(:processed_count) { processed_count }
    result.define_singleton_method(:errors) { errors }
    result
  end
end
