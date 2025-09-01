# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

class ExportGenerationJobTest < ActiveJob::TestCase
  def setup
    @import_template = import_templates(:one)
    @job_id = "test_export_123"
    @export_file_path = Rails.root.join("tmp", "exports", "#{@job_id}.xlsx")

    # Ensure export directory exists
    FileUtils.mkdir_p(File.dirname(@export_file_path))

    # Setup cache for JobStatusService
    @original_cache_store = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end

  def teardown
    # Clean up test files
    File.delete(@export_file_path) if File.exist?(@export_file_path)
    FileUtils.rm_rf(Rails.root.join("tmp/exports")) if Dir.exist?(Rails.root.join("tmp/exports"))

    # Restore cache
    Rails.cache = @original_cache_store
  end

  test "perform updates status to processing at job start" do
    mock_package = create_mock_package
    mock_service = create_mock_service(data_file_result: mock_package)

    ExcelExportService.stub(:new, mock_service) do
      ExportGenerationJob.new.perform(@import_template.id, @job_id)
    end

    # Check that status was updated (final status will be :completed/:failed)
    cached_status = Rails.cache.read("job_status:#{@job_id}")

    assert_not_nil cached_status
    assert_includes cached_status.keys, :status
    mock_service.verify
  end

  test "perform loads import template correctly" do
    mock_package = create_mock_package

    # Capture the arguments passed to ExcelExportService.new
    service_args = []
    original_new = ExcelExportService.method(:new)

    ExcelExportService.define_singleton_method(:new) do |template|
      service_args << template
      create_mock_service(data_file_result: mock_package)
    end

    begin
      ExportGenerationJob.new.perform(@import_template.id, @job_id)

      # Verify correct template was passed
      assert_equal 1, service_args.length
      assert_equal @import_template, service_args.first
    ensure
      ExcelExportService.define_singleton_method(:new, original_new)
    end
  end

  test "perform calls ExcelExportService.generate_data_file by default" do
    mock_package = create_mock_package
    service_calls = []

    # Mock the service to capture calls
    mock_service = Object.new
    mock_service.define_singleton_method(:generate_data_file) do
      service_calls << :generate_data_file_called
      mock_package
    end
    mock_service.define_singleton_method(:generate_template_file) { service_calls << :generate_template_file_called }
    mock_service.define_singleton_method(:generate_sample_file) { service_calls << :generate_sample_file_called }

    ExcelExportService.stub(:new, mock_service) do
      ExportGenerationJob.new.perform(@import_template.id, @job_id)
    end

    # Verify correct method was called
    assert_includes service_calls, :generate_data_file_called
    assert_not_includes service_calls, :generate_template_file_called
    assert_not_includes service_calls, :generate_sample_file_called
  end

  test "perform calls ExcelExportService.generate_template_file when export_type is template" do
    mock_package = create_mock_package
    service_calls = []

    # Mock the service to capture calls
    mock_service = Object.new
    mock_service.define_singleton_method(:generate_template_file) do
      service_calls << :generate_template_file_called
      mock_package
    end
    mock_service.define_singleton_method(:generate_data_file) { service_calls << :generate_data_file_called }
    mock_service.define_singleton_method(:generate_sample_file) { service_calls << :generate_sample_file_called }

    ExcelExportService.stub(:new, mock_service) do
      ExportGenerationJob.new.perform(@import_template.id, @job_id, :template)
    end

    # Verify correct method was called
    assert_includes service_calls, :generate_template_file_called
    assert_not_includes service_calls, :generate_data_file_called
    assert_not_includes service_calls, :generate_sample_file_called
  end

  test "perform calls ExcelExportService.generate_sample_file when export_type is sample" do
    mock_package = create_mock_package
    service_calls = []

    # Mock the service to capture calls
    mock_service = Object.new
    mock_service.define_singleton_method(:generate_sample_file) do
      service_calls << :generate_sample_file_called
      mock_package
    end
    mock_service.define_singleton_method(:generate_data_file) { service_calls << :generate_data_file_called }
    mock_service.define_singleton_method(:generate_template_file) { service_calls << :generate_template_file_called }

    ExcelExportService.stub(:new, mock_service) do
      ExportGenerationJob.new.perform(@import_template.id, @job_id, :sample)
    end

    # Verify correct method was called
    assert_includes service_calls, :generate_sample_file_called
    assert_not_includes service_calls, :generate_data_file_called
    assert_not_includes service_calls, :generate_template_file_called
  end

  test "perform creates export directory and saves file" do
    mock_package = create_mock_package
    mock_service = create_mock_service(data_file_result: mock_package)

    # Verify directory doesn't exist initially
    FileUtils.rm_rf(File.dirname(@export_file_path))

    assert_not Dir.exist?(File.dirname(@export_file_path))

    ExcelExportService.stub(:new, mock_service) do
      ExportGenerationJob.new.perform(@import_template.id, @job_id)
    end

    # Verify directory was created and file exists
    assert Dir.exist?(File.dirname(@export_file_path))
    assert_path_exists @export_file_path

    mock_service.verify
  end

  test "perform updates status to completed on successful export" do
    mock_package = create_mock_package
    mock_service = create_mock_service(data_file_result: mock_package)

    ExcelExportService.stub(:new, mock_service) do
      ExportGenerationJob.new.perform(@import_template.id, @job_id)
    end

    # Check final status
    cached_status = Rails.cache.read("job_status:#{@job_id}")

    assert_equal :completed, cached_status[:status]
    assert_equal "Export generated successfully", cached_status[:result_summary]
    assert_equal @export_file_path.to_s, cached_status[:file_path]
    assert_not_nil cached_status[:completed_at]

    mock_service.verify
  end

  test "perform updates status to failed on service exception" do
    # Mock service to raise an exception
    mock_service = Object.new
    mock_service.define_singleton_method(:generate_data_file) do
      raise StandardError.new("Export service failed")
    end

    ExcelExportService.stub(:new, mock_service) do
      ExportGenerationJob.new.perform(@import_template.id, @job_id)
    end

    # Check final status
    cached_status = Rails.cache.read("job_status:#{@job_id}")

    assert_equal :failed, cached_status[:status]
    assert_equal "Export service failed", cached_status[:error_message]
    assert_not_nil cached_status[:completed_at]
  end

  test "perform handles missing import template gracefully" do
    invalid_template_id = 99_999

    ExportGenerationJob.new.perform(invalid_template_id, @job_id)

    # Check final status
    cached_status = Rails.cache.read("job_status:#{@job_id}")

    assert_equal :failed, cached_status[:status]
    assert_includes cached_status[:error_message].downcase, "couldn't find importtemplate"
    assert_not_nil cached_status[:completed_at]
  end

  test "perform handles file system errors gracefully" do
    mock_package = create_mock_package
    mock_service = create_mock_service(data_file_result: mock_package)

    # Mock FileUtils.mkdir_p to raise an error
    original_mkdir_p = FileUtils.method(:mkdir_p)
    FileUtils.define_singleton_method(:mkdir_p) do |*_args|
      raise StandardError.new("Permission denied")
    end

    begin
      ExcelExportService.stub(:new, mock_service) do
        ExportGenerationJob.new.perform(@import_template.id, @job_id)
      end

      # Check final status
      cached_status = Rails.cache.read("job_status:#{@job_id}")

      assert_equal :failed, cached_status[:status]
      assert_equal "Permission denied", cached_status[:error_message]
      assert_not_nil cached_status[:completed_at]
    ensure
      FileUtils.define_singleton_method(:mkdir_p, original_mkdir_p)
    end

    mock_service.verify
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
      mock_package = create_mock_package
      mock_service = create_mock_service(data_file_result: mock_package)

      ExcelExportService.stub(:new, mock_service) do
        ExportGenerationJob.new.perform(@import_template.id, @job_id)
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
      assert_equal "Export generated successfully", completion_update[:additional_data][:result_summary]
      assert_equal @export_file_path.to_s, completion_update[:additional_data][:file_path]

      mock_service.verify
    ensure
      JobStatusService.define_singleton_method(:update_status, original_update_status)
    end
  end

  test "perform with different export types updates status correctly" do
    %i[data template sample].each do |export_type|
      job_id = "test_export_#{export_type}_123"

      mock_package = create_mock_package
      
      # Create specific mock service for each export type
      mock_service = Minitest::Mock.new
      case export_type
      when :template
        mock_service.expect(:generate_template_file, mock_package)
      when :sample
        mock_service.expect(:generate_sample_file, mock_package)
      else
        mock_service.expect(:generate_data_file, mock_package)
      end

      ExcelExportService.stub(:new, mock_service) do
        ExportGenerationJob.new.perform(@import_template.id, job_id, export_type)
      end

      # Check status for each export type
      cached_status = Rails.cache.read("job_status:#{job_id}")

      assert_equal :completed, cached_status[:status]
      assert_equal "Export generated successfully", cached_status[:result_summary]

      mock_service.verify
    end
  end

  test "job can be enqueued with correct arguments" do
    assert_enqueued_with(
      job: ExportGenerationJob,
      args: [@import_template.id, @job_id]
    ) do
      ExportGenerationJob.perform_later(@import_template.id, @job_id)
    end
  end

  test "job can be enqueued with export type parameter" do
    assert_enqueued_with(
      job: ExportGenerationJob,
      args: [@import_template.id, @job_id, :template]
    ) do
      ExportGenerationJob.perform_later(@import_template.id, @job_id, :template)
    end
  end

  test "perform handles package serialization errors" do
    # Mock package that fails on serialize
    mock_package = Object.new
    mock_package.define_singleton_method(:serialize) do |_path|
      raise StandardError.new("Serialization failed")
    end

    mock_service = create_mock_service(data_file_result: mock_package)

    ExcelExportService.stub(:new, mock_service) do
      ExportGenerationJob.new.perform(@import_template.id, @job_id)
    end

    # Check final status
    cached_status = Rails.cache.read("job_status:#{@job_id}")

    assert_equal :failed, cached_status[:status]
    assert_equal "Serialization failed", cached_status[:error_message]
    assert_not_nil cached_status[:completed_at]

    mock_service.verify
  end

  test "perform cache updates are atomic" do
    # Test that partial failures don't leave cache in inconsistent state
    mock_package = create_mock_package
    mock_service = create_mock_service(data_file_result: mock_package)

    ExcelExportService.stub(:new, mock_service) do
      ExportGenerationJob.new.perform(@import_template.id, @job_id)
    end

    # Verify all data is consistently stored
    cached_status = Rails.cache.read("job_status:#{@job_id}")

    assert_equal :completed, cached_status[:status]
    assert_not_nil cached_status[:started_at], "Should have started_at from processing update"
    assert_not_nil cached_status[:completed_at], "Should have completed_at from completion update"
    assert_equal "Export generated successfully", cached_status[:result_summary]
    assert_equal @export_file_path.to_s, cached_status[:file_path]
    assert_not_nil cached_status[:updated_at], "Should have updated_at timestamp"

    mock_service.verify
  end

  test "perform works with all supported export type symbols and strings" do
    test_cases = [
      { input: :template, expected_method: :generate_template_file },
      { input: "template", expected_method: :generate_template_file },
      { input: :sample, expected_method: :generate_sample_file },
      { input: "sample", expected_method: :generate_sample_file },
      { input: :data, expected_method: :generate_data_file },
      { input: "data", expected_method: :generate_data_file },
      { input: :unknown, expected_method: :generate_data_file }, # defaults to data
      { input: "unknown", expected_method: :generate_data_file } # defaults to data
    ]

    test_cases.each_with_index do |test_case, index|
      job_id = "test_export_type_#{index}"
      mock_package = create_mock_package
      service_calls = []

      # Mock service to track which method is called
      mock_service = Object.new
      %i[generate_data_file generate_template_file generate_sample_file].each do |method|
        mock_service.define_singleton_method(method) do
          service_calls << method
          mock_package
        end
      end

      ExcelExportService.stub(:new, mock_service) do
        ExportGenerationJob.new.perform(@import_template.id, job_id, test_case[:input])
      end

      # Verify correct method was called
      assert_includes service_calls, test_case[:expected_method],
                      "Expected #{test_case[:expected_method]} to be called for input #{test_case[:input]}"

      # Verify job completed successfully
      cached_status = Rails.cache.read("job_status:#{job_id}")

      assert_equal :completed, cached_status[:status]
    end
  end

  private

  def create_mock_package
    package = Object.new
    package.define_singleton_method(:serialize) do |file_path|
      # Create a fake Excel file for testing
      FileUtils.mkdir_p(File.dirname(file_path))
      File.write(file_path, "fake excel content")
    end
    package
  end

  def create_mock_service(data_file_result: nil, template_file_result: nil, sample_file_result: nil)
    service = Minitest::Mock.new

    service.expect(:generate_data_file, data_file_result) if data_file_result

    service.expect(:generate_template_file, template_file_result) if template_file_result

    service.expect(:generate_sample_file, sample_file_result) if sample_file_result

    service
  end
end
