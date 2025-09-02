# frozen_string_literal: true

require "test_helper"

class ExcelImportServiceErrorHandlingTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @template = ImportTemplate.create!(
      name: "Error Testing Template",
      description: "Template for testing error scenarios",
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

    @date_column = @template.template_columns.create!(
      name: "Birth Date",
      data_type: "date",
      column_number: 3,
      required: false
    )

    @boolean_column = @template.template_columns.create!(
      name: "Active",
      data_type: "boolean",
      column_number: 4,
      required: false
    )
  end

  test "should provide meaningful error message for missing required field" do
    excel_data = [
      ["Name", "Age", "Birth Date", "Active"],
      ["", "25", "2000-01-01", "true"] # Missing required name
    ]

    file = create_test_excel_file(excel_data)
    service = ExcelImportService.new(file, @template)
    result = service.process_import

    assert_not result.success
    assert_predicate result, :has_errors?
    
    # Check that error message is meaningful for cache storage
    error_message = result.errors.join("; ")
    assert_includes error_message, "Required field 'Name' cannot be empty"
    assert_includes error_message, "Row 2"
    
    # Ensure error message is concise and informative for background job status
    assert error_message.length < 200, "Error message should be concise for cache storage"
    assert_match /Row \d+/, error_message, "Error should include row number for debugging"
  end

  test "should provide meaningful error message for invalid number format" do
    excel_data = [
      ["Name", "Age", "Birth Date", "Active"],
      ["John Doe", "not_a_number", "2000-01-01", "true"]
    ]

    file = create_test_excel_file(excel_data)
    service = ExcelImportService.new(file, @template)
    result = service.process_import

    assert_not result.success
    assert_predicate result, :has_errors?
    
    error_message = result.errors.join("; ")
    assert_includes error_message, "Could not convert 'not_a_number' to number"
    assert_includes error_message, "Row 2"
    
    # Error message should be specific enough for troubleshooting
    assert_match /Could not convert .+ to number/, error_message
  end

  test "should provide meaningful error message for invalid date format" do
    excel_data = [
      ["Name", "Age", "Birth Date", "Active"],
      ["John Doe", "25", "not_a_date", "true"]
    ]

    file = create_test_excel_file(excel_data)
    service = ExcelImportService.new(file, @template)
    result = service.process_import

    assert_not result.success
    assert_predicate result, :has_errors?
    
    error_message = result.errors.join("; ")
    assert_includes error_message, "Could not convert 'not_a_date' to date"
    assert_includes error_message, "Row 2"
  end

  test "should provide meaningful error message for invalid boolean format" do
    excel_data = [
      ["Name", "Age", "Birth Date", "Active"],
      ["John Doe", "25", "2000-01-01", "maybe"]
    ]

    file = create_test_excel_file(excel_data)
    service = ExcelImportService.new(file, @template)
    result = service.process_import

    assert_not result.success
    assert_predicate result, :has_errors?
    
    error_message = result.errors.join("; ")
    assert_includes error_message, "Could not convert 'maybe' to boolean"
    assert_includes error_message, "Use true/false, yes/no, or 1/0"
    assert_includes error_message, "Row 2"
  end

  test "should provide meaningful error message for invalid file format" do
    # Test with empty file
    service = ExcelImportService.new(nil, @template)
    result = service.process_import

    assert_not result.success
    assert_predicate result, :has_errors?
    
    error_message = result.errors.join("; ")
    assert_equal "No file provided", error_message
    
    # Error should be clear and actionable
    assert error_message.length < 50, "File error should be concise"
  end

  test "should provide meaningful error message for file that cannot be read" do
    # Create a mock file that will cause Roo to fail
    mock_file = ActionDispatch::Http::UploadedFile.new(
      tempfile: Tempfile.new,
      filename: "corrupt.xlsx",
      type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    )
    
    # Write invalid content that will cause Roo to fail
    mock_file.tempfile.write("not valid excel content")
    mock_file.tempfile.rewind

    service = ExcelImportService.new(mock_file, @template)
    result = service.process_import

    assert_not result.success
    assert_predicate result, :has_errors?
    
    error_message = result.errors.join("; ")
    assert_includes error_message, "Could not read Excel file"
    
    # Should include some indication of what went wrong
    assert error_message.length > 20, "Error should provide some detail about the issue"
  end

  test "should provide meaningful error message for missing header validation" do
    # Create Excel with wrong headers
    excel_data = [
      ["Wrong Header", "Another Wrong", "Header"],
      ["John Doe", "25", "true"]
    ]

    file = create_test_excel_file(excel_data)
    service = ExcelImportService.new(file, @template)
    result = service.process_import

    assert_not result.success
    assert_predicate result, :has_errors?
    
    error_message = result.errors.join("; ")
    
    # Should indicate which headers are missing/wrong
    assert error_message.length > 10, "Header validation error should be descriptive"
    assert_not_includes error_message, "Row", "Header validation errors shouldn't reference row numbers"
  end

  test "should provide meaningful error message for non-existent record ID" do
    excel_data = [
      ["__record_id", "Name", "Age", "Birth Date", "Active"],
      [99_999, "John Doe", "25", "2000-01-01", "true"]
    ]

    file = create_test_excel_file(excel_data)
    service = ExcelImportService.new(file, @template)
    result = service.process_import

    assert_not result.success
    assert_predicate result, :has_errors?
    
    error_message = result.errors.join("; ")
    assert_includes error_message, "Record with ID 99999 not found"
    assert_includes error_message, "Row 2"
    
    # Should be specific about which ID was not found
    assert_match /Record with ID \d+ not found/, error_message
  end

  test "should aggregate multiple error messages meaningfully for cache storage" do
    excel_data = [
      ["Name", "Age", "Birth Date", "Active"],
      ["", "not_a_number", "not_a_date", "maybe"], # Multiple errors in one row
      ["Valid Name", "invalid_number", "2000-01-01", "true"], # Another error
      ["Another Valid", "25", "invalid_date", "false"] # Yet another error
    ]

    file = create_test_excel_file(excel_data)
    service = ExcelImportService.new(file, @template)
    result = service.process_import

    assert_not result.success
    assert_predicate result, :has_errors?
    assert result.errors.length >= 3, "Should capture multiple errors"
    
    # Check that all errors reference row numbers for debugging
    result.errors.each do |error|
      assert_match /Row \d+/, error, "Each error should reference a row number: #{error}"
    end
    
    # Combined error message should still be reasonable for cache storage
    combined_message = result.errors.join("; ")
    assert combined_message.length < 500, "Combined error message should be reasonable for cache"
    
    # Should include different types of validation errors
    assert_includes combined_message, "Required field"
    assert_includes combined_message, "Could not convert"
  end

  test "should provide concise transaction failure error message" do
    # Create a scenario that will cause transaction failure by trying to violate a constraint
    # We'll create an invalid operation that would cause the service to catch and handle the error
    
    # Create Excel data that would pass validation but cause a transaction issue
    excel_data = [
      ["Name", "Age", "Birth Date", "Active"],
      ["John Doe", "25", "2000-01-01", "true"]
    ]

    file = create_test_excel_file(excel_data)
    service = ExcelImportService.new(file, @template)
    
    # Mock the execute_sync_transaction method to simulate a database error
    service.define_singleton_method(:execute_sync_transaction) do |sync_plan|
      @import_result.success = false
      @import_result.add_error("Transaction failed: Connection lost")
    end
    
    result = service.process_import

    assert_not result.success
    assert_predicate result, :has_errors?
    
    error_message = result.errors.join("; ")
    assert_includes error_message, "Transaction failed"
    assert_includes error_message, "Connection lost"
    
    # Should be clear that this was a system-level failure
    assert error_message.length < 100, "Transaction error should be concise"
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