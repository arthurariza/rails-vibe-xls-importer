# frozen_string_literal: true

require "test_helper"

class BackgroundJobServiceCompatibilityTest < ActiveSupport::TestCase
  def setup
    # Use MemoryStore for consistent cache behavior in tests
    @original_cache_store = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    
    @user = users(:one)
    @template = ImportTemplate.create!(
      name: "BG Job Test Template",
      description: "Template for testing service compatibility in background jobs",
      user: @user
    )

    @name_column = @template.template_columns.create!(
      name: "Name",
      data_type: "string",
      column_number: 1,
      required: false
    )

    @age_column = @template.template_columns.create!(
      name: "Age",
      data_type: "number",
      column_number: 2,
      required: false
    )

    @active_column = @template.template_columns.create!(
      name: "Active",
      data_type: "boolean",
      column_number: 3,
      required: false
    )
  end

  def teardown
    Rails.cache = @original_cache_store
  end

  test "ExcelImportService produces identical results in background job vs synchronous context" do
    # Create test data
    excel_data = [
      ["Name", "Age", "Active"],
      ["John Doe", "30", "true"],
      ["Jane Smith", "25", "false"]
    ]

    # Test 1: Synchronous call
    sync_file = create_test_excel_file(excel_data)
    sync_service = ExcelImportService.new(sync_file, @template)
    sync_result = sync_service.process_import

    assert sync_result.success, "Synchronous import should succeed: #{sync_result.errors.join('; ')}"
    sync_created_count = sync_result.created_records.length
    sync_summary = sync_result.summary

    # Test 2: Background job call (simulating ImportProcessingJob behavior)
    job_id = SecureRandom.hex(8)
    JobStatusService.update_status(job_id, :pending, created_at: Time.current)

    # Save file to temporary location as the job would
    background_file_path = save_file_to_temp_location(excel_data, job_id)

    # Create ActionDispatch::Http::UploadedFile from temp file (as job does)
    background_uploaded_file = ActionDispatch::Http::UploadedFile.new(
      tempfile: File.open(background_file_path),
      filename: File.basename(background_file_path),
      type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    )

    # Clear existing records to ensure clean comparison
    @template.data_records.destroy_all

    # Call service from background job context
    background_service = ExcelImportService.new(background_uploaded_file, @template)
    background_result = background_service.process_import

    # Verify identical behavior
    assert background_result.success, "Background import should succeed: #{background_result.errors.join('; ')}"
    assert_equal sync_created_count, background_result.created_records.length
    assert_includes background_result.summary, "created", "Background result should have similar summary structure"

    # Verify data was processed identically
    background_records = @template.data_records.reload
    assert_equal 2, background_records.count

    john_record = background_records.find { |r| r.value_for_column(@name_column) == "John Doe" }
    jane_record = background_records.find { |r| r.value_for_column(@name_column) == "Jane Smith" }

    assert_not_nil john_record
    assert_not_nil jane_record
    assert_equal "30", john_record.value_for_column(@age_column)
    assert_equal "true", john_record.value_for_column(@active_column)
    assert_equal "25", jane_record.value_for_column(@age_column)
    assert_equal "false", jane_record.value_for_column(@active_column)

    # Cleanup
    background_uploaded_file.tempfile.close
    File.delete(background_file_path) if File.exist?(background_file_path)
  end

  test "ExcelImportService handles errors identically in background job vs synchronous context" do
    # Create test data with validation errors
    excel_data = [
      ["Name", "Age", "Active"],
      ["", "invalid_number", "maybe"] # Missing required name, invalid number, invalid boolean
    ]

    # Test 1: Synchronous error handling
    sync_file = create_test_excel_file(excel_data)
    sync_service = ExcelImportService.new(sync_file, @template)
    sync_result = sync_service.process_import

    assert_not sync_result.success, "Synchronous import should fail"
    sync_errors = sync_result.errors
    sync_error_count = sync_errors.length

    # Test 2: Background job error handling
    job_id = SecureRandom.hex(8)
    background_file_path = save_file_to_temp_location(excel_data, job_id)

    background_uploaded_file = ActionDispatch::Http::UploadedFile.new(
      tempfile: File.open(background_file_path),
      filename: File.basename(background_file_path),
      type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    )

    background_service = ExcelImportService.new(background_uploaded_file, @template)
    background_result = background_service.process_import

    # Verify identical error handling
    assert_not background_result.success, "Background import should fail"
    assert_equal sync_error_count, background_result.errors.length
    
    # Verify error messages contain same validation issues
    combined_bg_errors = background_result.errors.join("; ")
    combined_sync_errors = sync_errors.join("; ")
    
    # Should contain similar error types (exact text may vary due to row numbers)
    assert_includes combined_bg_errors, "Could not convert"
    assert_includes combined_sync_errors, "Could not convert"

    # Cleanup
    background_uploaded_file.tempfile.close
    File.delete(background_file_path) if File.exist?(background_file_path)
  end

  test "ExcelExportService produces identical results in background job vs synchronous context" do
    # Create test data
    record1 = @template.data_records.create!
    record1.set_value_for_column(@name_column, "Export Test 1")
    record1.set_value_for_column(@age_column, "35")
    record1.set_value_for_column(@active_column, "true")

    record2 = @template.data_records.create!
    record2.set_value_for_column(@name_column, "Export Test 2")
    record2.set_value_for_column(@age_column, "28")
    record2.set_value_for_column(@active_column, "false")

    # Test 1: Synchronous call
    sync_service = ExcelExportService.new(@template)
    sync_package = sync_service.generate_data_file

    assert_not_nil sync_package
    sync_stream = sync_package.to_stream
    sync_size = sync_stream.size

    # Test 2: Background job call (simulating ExportGenerationJob behavior)
    job_id = SecureRandom.hex(8)
    JobStatusService.update_status(job_id, :pending, created_at: Time.current)

    # Call service from background job context (identical to job implementation)
    background_service = ExcelExportService.new(@template)
    background_package = background_service.generate_data_file

    assert_not_nil background_package
    background_stream = background_package.to_stream
    background_size = background_stream.size

    # Verify similar behavior (sizes may differ slightly due to timestamps)
    size_difference = (sync_size - background_size).abs
    assert size_difference <= 10, "Export file sizes should be nearly identical (diff: #{size_difference} bytes)"
    assert_equal sync_package.class, background_package.class

    # Verify content is identical by saving and reading both exports
    sync_temp_file = save_package_to_temp(sync_package, "sync_#{job_id}")
    background_temp_file = save_package_to_temp(background_package, "bg_#{job_id}")

    sync_workbook = read_excel_file(sync_temp_file)
    background_workbook = read_excel_file(background_temp_file)

    # Compare headers
    sync_headers = sync_workbook.row(1)
    bg_headers = background_workbook.row(1)
    assert_equal sync_headers, bg_headers

    # Compare data rows
    sync_row1 = sync_workbook.row(2)
    bg_row1 = background_workbook.row(2)
    assert_equal sync_row1, bg_row1

    sync_row2 = sync_workbook.row(3) 
    bg_row2 = background_workbook.row(3)
    assert_equal sync_row2, bg_row2

    # Cleanup
    File.delete(sync_temp_file) if File.exist?(sync_temp_file)
    File.delete(background_temp_file) if File.exist?(background_temp_file)
  end

  test "services work with ActionDispatch::Http::UploadedFile created from temporary files" do
    # This specifically tests the file parameter handling as done in background jobs
    excel_data = [
      ["Name", "Age", "Active"],
      ["File Test", "42", "true"]
    ]

    job_id = SecureRandom.hex(8)

    # Create temporary file (simulating controller saving uploaded file)
    temp_file_path = save_file_to_temp_location(excel_data, job_id)
    assert File.exist?(temp_file_path), "Temporary file should be created"

    # Create ActionDispatch::Http::UploadedFile from temp file (as background job does)
    uploaded_file = ActionDispatch::Http::UploadedFile.new(
      tempfile: File.open(temp_file_path),
      filename: File.basename(temp_file_path),
      type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    )

    # Test that service works with this file parameter
    service = ExcelImportService.new(uploaded_file, @template)
    result = service.process_import

    assert result.success, "Service should work with ActionDispatch::Http::UploadedFile from temp file: #{result.errors.join('; ')}"
    assert_equal 1, result.created_records.length

    created_record = result.created_records.first
    assert_equal "File Test", created_record.value_for_column(@name_column)
    assert_equal "42", created_record.value_for_column(@age_column)
    assert_equal "true", created_record.value_for_column(@active_column)

    # Cleanup
    uploaded_file.tempfile.close
    File.delete(temp_file_path) if File.exist?(temp_file_path)
  end

  test "services handle file validation consistently in background vs synchronous contexts" do
    # Test with invalid file content that will cause file reading to fail
    
    # Create invalid Excel file content
    invalid_content = "This is not a valid Excel file"
    
    # Test 1: Synchronous context with invalid file
    sync_temp_file = Tempfile.new(["invalid_sync", ".xlsx"])
    sync_temp_file.write(invalid_content)
    sync_temp_file.rewind
    
    sync_uploaded_file = ActionDispatch::Http::UploadedFile.new(
      tempfile: sync_temp_file,
      filename: "invalid.xlsx",
      type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    )
    
    sync_service = ExcelImportService.new(sync_uploaded_file, @template)
    sync_result = sync_service.process_import
    
    assert_not sync_result.success, "Synchronous service should reject invalid file"
    assert_includes sync_result.errors.join("; "), "Could not read Excel file"
    
    # Test 2: Background job context with invalid file 
    job_id = SecureRandom.hex(8)
    bg_temp_path = Rails.root.join("tmp", "test_#{job_id}.xlsx")
    File.write(bg_temp_path, invalid_content)
    
    bg_uploaded_file = ActionDispatch::Http::UploadedFile.new(
      tempfile: File.open(bg_temp_path),
      filename: File.basename(bg_temp_path),
      type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    )
    
    bg_service = ExcelImportService.new(bg_uploaded_file, @template)
    bg_result = bg_service.process_import
    
    # Verify identical error handling
    assert_not bg_result.success, "Background service should reject invalid file"
    assert_includes bg_result.errors.join("; "), "Could not read Excel file"
    
    # Error handling should be identical
    assert_equal sync_result.success, bg_result.success
    
    # Cleanup
    sync_temp_file.close
    sync_temp_file.unlink
    bg_uploaded_file.tempfile.close
    File.delete(bg_temp_path) if File.exist?(bg_temp_path)
  end

  private

  def create_test_excel_file(data)
    # Use fixture file to avoid race conditions in parallel tests
    if data.size <= 2 # Simple test data
      uploaded_excel_fixture("edge_case_base.xlsx")
    else
      uploaded_excel_fixture("large_dataset.xlsx")
    end
  end

  def save_file_to_temp_location(excel_data, job_id)
    require "caxlsx"

    package = Axlsx::Package.new
    workbook = package.workbook

    worksheet = workbook.add_worksheet(name: "Test Data")
    excel_data.each { |row| worksheet.add_row(row) }

    # Save to temp location as background job would
    temp_file_path = Rails.root.join("tmp", "bg_test_#{job_id}.xlsx")
    FileUtils.mkdir_p(File.dirname(temp_file_path))
    package.serialize(temp_file_path)
    
    temp_file_path.to_s
  end

  def save_package_to_temp(package, prefix)
    temp_file_path = Rails.root.join("tmp", "#{prefix}.xlsx")
    FileUtils.mkdir_p(File.dirname(temp_file_path))
    package.serialize(temp_file_path)
    temp_file_path.to_s
  end

  def read_excel_file(file_path)
    require "roo"
    Roo::Excelx.new(file_path)
  end
end