# frozen_string_literal: true

require "test_helper"

class ExportServiceResultPatternTest < ActiveSupport::TestCase
  def setup
    # Use MemoryStore for consistent cache behavior in tests
    @original_cache_store = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    
    @user = users(:one)
    @template = ImportTemplate.create!(
      name: "Export Pattern Test Template",
      description: "Template for testing export service result pattern",
      user: @user
    )

    @name_column = @template.template_columns.create!(
      name: "Name",
      data_type: "string",
      column_number: 1,
      required: false
    )

    # Create test data
    record = @template.data_records.create!
    record.set_value_for_column(@name_column, "Test Data")
  end

  def teardown
    Rails.cache = @original_cache_store
  end

  test "ExcelExportService does not return structured result object like ExcelImportService" do
    # Test ExcelImportService pattern for comparison
    excel_data = [["Name"], ["Test Import"]]
    import_file = create_test_excel_file(excel_data)
    import_service = ExcelImportService.new(import_file, @template)
    import_result = import_service.process_import

    # ImportResult has structured response
    assert_respond_to import_result, :success
    assert_respond_to import_result, :errors
    assert_respond_to import_result, :summary
    assert import_result.is_a?(ExcelImportService::ImportResult)

    # Test ExcelExportService pattern
    export_service = ExcelExportService.new(@template)
    export_result = export_service.generate_data_file

    # ExportService returns Axlsx::Package directly - NO structured result
    assert export_result.is_a?(Axlsx::Package)
    assert_not_respond_to export_result, :success
    assert_not_respond_to export_result, :errors
    assert_not_respond_to export_result, :summary

    # This demonstrates the inconsistency between services
    assert_not_equal import_result.class.name, export_result.class.name
  end

  test "ExportGenerationJob compensates for lack of structured result object" do
    job_id = SecureRandom.hex(8)

    # Initialize job status
    JobStatusService.update_status(job_id, :pending, created_at: Time.current)

    # Run export job
    job = ExportGenerationJob.new
    job.perform(@template.id, job_id, :data)

    # Check final job status
    cached_status = JobStatusService.get_status(job_id)
    
    assert_equal :completed, cached_status[:status]
    assert_equal "Export generated successfully", cached_status[:result_summary]
    
    # Note: This generic message is created by the job, not the service
    # Compare to import jobs which get detailed summaries from ImportResult.summary
  end

  test "ExportGenerationJob handles service exceptions at job level not service level" do
    job_id = SecureRandom.hex(8)
    
    # Initialize job status
    JobStatusService.update_status(job_id, :pending, created_at: Time.current)

    # Create a scenario that will cause an exception in the export service
    # by using a template that doesn't exist
    invalid_template_id = 99999

    job = ExportGenerationJob.new
    job.perform(invalid_template_id, job_id, :data)

    # Check that job caught the exception and set failed status
    cached_status = JobStatusService.get_status(job_id)
    
    assert_equal :failed, cached_status[:status]
    assert_includes cached_status[:error_message], "Couldn't find ImportTemplate"
    
    # This error message is generic ActiveRecord error, not a meaningful service-level message
    # Compare to ImportResult which provides specific validation errors with row numbers
  end

  test "demonstrates what would be needed for consistent result pattern" do
    # This test documents what ExcelExportService would need to be consistent
    
    # Current ExcelExportService usage:
    service = ExcelExportService.new(@template)
    package = service.generate_data_file
    
    # What we have now:
    assert package.is_a?(Axlsx::Package)
    assert_respond_to package, :to_stream
    
    # What would be consistent with ExcelImportService pattern:
    # result = service.generate_data_file  # Should return ExportResult
    # assert result.respond_to?(:success)
    # assert result.respond_to?(:errors)
    # assert result.respond_to?(:summary)
    # assert result.respond_to?(:package) or result.respond_to?(:file_path)
    # 
    # if result.success
    #   package = result.package
    #   summary = result.summary  # e.g., "Generated 1 record with 2 columns"
    # else
    #   errors = result.errors    # e.g., ["Template has no columns", "Missing required data"]
    # end
  end

  private

  def create_test_excel_file(data)
    require "caxlsx"

    package = Axlsx::Package.new
    workbook = package.workbook

    worksheet = workbook.add_worksheet(name: "Test Data")
    data.each { |row| worksheet.add_row(row) }

    # Create temporary file
    temp_file = Tempfile.new(["test_import", ".xlsx"])
    temp_file.binmode
    temp_file.write(package.to_stream.string)
    temp_file.rewind

    # Create ActionDispatch::Http::UploadedFile-like object
    ActionDispatch::Http::UploadedFile.new(
      tempfile: temp_file,
      filename: "test_import.xlsx",
      type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    )
  end
end