# frozen_string_literal: true

require "test_helper"

class ExcelImportServiceTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @template = ImportTemplate.create!(
      name: "Test Import Template",
      description: "Template for testing imports",
      user: @user,
      column_definitions: {
        "column_1" => { "name" => "Name", "data_type" => "string" },
        "column_2" => { "name" => "Age", "data_type" => "number" },
        "column_3" => { "name" => "Active", "data_type" => "boolean" }
      }
    )

    # Create existing records for sync testing
    @existing_record_1 = @template.data_records.create!(
      column_1: "John Doe",
      column_2: "30",
      column_3: "true"
    )

    @existing_record_2 = @template.data_records.create!(
      column_1: "Jane Smith",
      column_2: "25",
      column_3: "false"
    )
  end

  test "should synchronize data with ID column - update existing records" do
    # Create Excel file with ID column that updates existing records
    excel_data = [
      ["__record_id", "Name", "Age", "Active"],
      [@existing_record_1.id, "John Updated", "31", "false"],
      [@existing_record_2.id, "Jane Updated", "26", "true"]
    ]

    file = create_test_excel_file(excel_data)
    service = ExcelImportService.new(file, @template)
    result = service.process_import

    assert result.success, "Import should succeed"
    assert_equal 2, result.updated_count
    assert_equal 0, result.success_count # no new records created
    assert_equal 0, result.deleted_count

    # Verify records were updated
    @existing_record_1.reload

    assert_equal "John Updated", @existing_record_1.column_1
    assert_equal "31", @existing_record_1.column_2
    assert_equal "false", @existing_record_1.column_3

    @existing_record_2.reload

    assert_equal "Jane Updated", @existing_record_2.column_1
    assert_equal "26", @existing_record_2.column_2
    assert_equal "true", @existing_record_2.column_3
  end

  test "should synchronize data with ID column - create new and delete missing" do
    # Create Excel file with one existing record, one new record, missing the second existing record
    excel_data = [
      ["__record_id", "Name", "Age", "Active"],
      [@existing_record_1.id, "John Updated", "31", "false"],
      ["", "Bob New", "35", "true"] # Empty ID means new record
    ]

    file = create_test_excel_file(excel_data)
    service = ExcelImportService.new(file, @template)
    result = service.process_import

    assert result.success, "Import should succeed"
    assert_equal 1, result.updated_count # existing_record_1 updated
    assert_equal 1, result.success_count # new record created
    assert_equal 1, result.deleted_count # existing_record_2 deleted

    # Verify existing_record_1 was updated
    @existing_record_1.reload

    assert_equal "John Updated", @existing_record_1.column_1

    # Verify existing_record_2 was deleted
    assert_not DataRecord.exists?(@existing_record_2.id)

    # Verify new record was created
    new_record = @template.data_records.where.not(id: [@existing_record_1.id]).first

    assert_not_nil new_record
    assert_equal "Bob New", new_record.column_1
    assert_equal "35", new_record.column_2
  end

  test "should create all new records when no ID column present" do
    # Create Excel file without ID column (legacy behavior for new files)
    excel_data = [
      ["Name", "Age", "Active"],
      ["Alice New", "28", "true"],
      ["Bob New", "32", "false"]
    ]

    file = create_test_excel_file(excel_data)
    service = ExcelImportService.new(file, @template)
    result = service.process_import

    assert result.success, "Import should succeed"
    assert_equal 0, result.updated_count # no updates
    assert_equal 2, result.success_count # 2 new records created
    assert_equal 0, result.deleted_count # no deletes without ID column

    # Original records should still exist
    assert DataRecord.exists?(@existing_record_1.id)
    assert DataRecord.exists?(@existing_record_2.id)

    # New records should be created
    assert_equal 4, @template.data_records.count # 2 existing + 2 new
  end

  test "should reject import if validation fails and preserve existing data" do
    # Create Excel file with invalid data
    excel_data = [
      ["__record_id", "Name", "Age", "Active"],
      [@existing_record_1.id, "John Updated", "invalid_number", "false"]
    ]

    file = create_test_excel_file(excel_data)
    service = ExcelImportService.new(file, @template)
    result = service.process_import

    assert_not result.success, "Import should fail due to validation error"
    assert_predicate result, :has_errors?

    # Verify no changes were made to existing records
    @existing_record_1.reload

    assert_equal "John Doe", @existing_record_1.column_1 # unchanged
    assert_equal "30", @existing_record_1.column_2 # unchanged
  end

  test "should handle non-existent ID in import file" do
    # Create Excel file with non-existent record ID
    excel_data = [
      ["__record_id", "Name", "Age", "Active"],
      [99_999, "Fake Record", "25", "true"] # Non-existent ID
    ]

    file = create_test_excel_file(excel_data)
    service = ExcelImportService.new(file, @template)
    result = service.process_import

    assert_not result.success, "Import should fail due to non-existent ID"
    assert_predicate result, :has_errors?
    assert_includes result.errors.join, "Record with ID 99999 not found"
  end

  test "should rollback transaction when validation fails partway through" do
    # Create Excel file with one valid record and one invalid record
    excel_data = [
      ["__record_id", "Name", "Age", "Active"],
      [@existing_record_1.id, "John Updated", "31", "true"], # Valid update
      ["", "New Record", "invalid_age", "true"] # Invalid new record
    ]

    original_count = @template.data_records.count
    original_name = @existing_record_1.column_1

    file = create_test_excel_file(excel_data)
    service = ExcelImportService.new(file, @template)
    result = service.process_import

    assert_not result.success, "Import should fail due to validation error"
    assert_predicate result, :has_errors?

    # Verify transaction rolled back - no changes should be made
    assert_equal original_count, @template.data_records.count
    @existing_record_1.reload

    assert_equal original_name, @existing_record_1.column_1 # Should be unchanged
  end

  test "should handle duplicate IDs in import file" do
    # Create Excel file with duplicate record IDs
    excel_data = [
      ["__record_id", "Name", "Age", "Active"],
      [@existing_record_1.id, "John First", "30", "true"],
      [@existing_record_1.id, "John Duplicate", "31", "false"] # Duplicate ID
    ]

    file = create_test_excel_file(excel_data)
    service = ExcelImportService.new(file, @template)
    result = service.process_import

    # Should process but the second occurrence will overwrite the first
    assert result.success, "Import should succeed with duplicate IDs"

    # The last occurrence should win
    @existing_record_1.reload

    assert_equal "John Duplicate", @existing_record_1.column_1
    assert_equal "31", @existing_record_1.column_2
  end

  test "should handle invalid ID formats" do
    # Create Excel file with non-numeric ID
    excel_data = [
      ["__record_id", "Name", "Age", "Active"],
      ["not_a_number", "Invalid ID Record", "25", "true"]
    ]

    file = create_test_excel_file(excel_data)
    service = ExcelImportService.new(file, @template)
    result = service.process_import

    # Should treat invalid ID as new record (ID converts to 0)
    assert result.success, "Import should succeed, treating invalid ID as new record"
    assert_equal 1, result.success_count # Should create new record

    # Should create new record since invalid ID is treated as no ID
    new_record = @template.data_records.where(column_1: "Invalid ID Record").first

    assert_not_nil new_record
  end

  test "should handle files without ID column (legacy behavior)" do
    # Create Excel file without ID column - should work as additive import
    excel_data = [
      ["Name", "Age", "Active"],
      ["Legacy Record", "40", "true"]
    ]

    original_count = @template.data_records.count

    file = create_test_excel_file(excel_data)
    service = ExcelImportService.new(file, @template)
    result = service.process_import

    assert result.success, "Import should succeed without ID column"
    assert_equal 1, result.success_count
    assert_equal 0, result.updated_count
    assert_equal 0, result.deleted_count

    # Should add to existing records (additive behavior when no ID column)
    assert_equal original_count + 1, @template.data_records.count

    # Original records should be unchanged
    @existing_record_1.reload

    assert_equal "John Doe", @existing_record_1.column_1
  end

  test "should handle empty ID values mixed with valid IDs" do
    # Create Excel file with mix of empty and valid IDs
    excel_data = [
      ["__record_id", "Name", "Age", "Active"],
      [@existing_record_1.id, "John Updated", "31", "true"], # Update existing
      ["", "New Record 1", "28", "false"], # Create new (empty ID)
      [nil, "New Record 2", "29", "true"] # Create new (nil ID)
    ]

    file = create_test_excel_file(excel_data)
    service = ExcelImportService.new(file, @template)
    result = service.process_import

    assert result.success, "Import should succeed with mixed ID values"
    assert_equal 1, result.updated_count # existing_record_1 updated
    assert_equal 2, result.success_count # 2 new records created
    assert_equal 1, result.deleted_count # existing_record_2 deleted (not in file)

    # Verify update occurred
    @existing_record_1.reload

    assert_equal "John Updated", @existing_record_1.column_1

    # Verify new records were created
    new_records = @template.data_records.where(column_1: ["New Record 1", "New Record 2"])

    assert_equal 2, new_records.count
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
