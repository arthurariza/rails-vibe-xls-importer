# frozen_string_literal: true

require "test_helper"

class ExcelImportServiceTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @template = ImportTemplate.create!(
      name: "Test Import Template",
      description: "Template for testing imports",
      user: @user
    )

    # Create template columns for dynamic column system
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

    # Create existing records for sync testing using new dynamic system
    @existing_record_1 = @template.data_records.create!
    @existing_record_1.set_value_for_column(@name_column, "John Doe")
    @existing_record_1.set_value_for_column(@age_column, "30")
    @existing_record_1.set_value_for_column(@active_column, "true")

    @existing_record_2 = @template.data_records.create!
    @existing_record_2.set_value_for_column(@name_column, "Jane Smith")
    @existing_record_2.set_value_for_column(@age_column, "25")
    @existing_record_2.set_value_for_column(@active_column, "false")
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

    assert result.success, "Import should succeed: #{result.errors.join('; ')}"
    assert_equal 2, result.updated_count
    assert_equal 0, result.success_count # no new records created
    assert_equal 0, result.deleted_count

    # Verify records were updated
    @existing_record_1.reload

    assert_equal "John Updated", @existing_record_1.value_for_column(@name_column)
    assert_equal "31", @existing_record_1.value_for_column(@age_column)
    assert_equal "false", @existing_record_1.value_for_column(@active_column)

    @existing_record_2.reload

    assert_equal "Jane Updated", @existing_record_2.value_for_column(@name_column)
    assert_equal "26", @existing_record_2.value_for_column(@age_column)
    assert_equal "true", @existing_record_2.value_for_column(@active_column)
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

    assert result.success, "Import should succeed: #{result.errors.join('; ')}"
    assert_equal 1, result.updated_count # existing_record_1 updated
    assert_equal 1, result.success_count # new record created
    assert_equal 1, result.deleted_count # existing_record_2 deleted

    # Verify existing_record_1 was updated
    @existing_record_1.reload

    assert_equal "John Updated", @existing_record_1.value_for_column(@name_column)

    # Verify existing_record_2 was deleted
    assert_not DataRecord.exists?(@existing_record_2.id)

    # Verify new record was created
    new_record = @template.data_records.where.not(id: [@existing_record_1.id]).first

    assert_not_nil new_record
    assert_equal "Bob New", new_record.value_for_column(@name_column)
    assert_equal "35", new_record.value_for_column(@age_column)
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

    assert_equal "John Doe", @existing_record_1.value_for_column(@name_column) # unchanged
    assert_equal "30", @existing_record_1.value_for_column(@age_column) # unchanged
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
    original_name = @existing_record_1.value_for_column(@name_column)

    file = create_test_excel_file(excel_data)
    service = ExcelImportService.new(file, @template)
    result = service.process_import

    assert_not result.success, "Import should fail due to validation error"
    assert_predicate result, :has_errors?

    # Verify transaction rolled back - no changes should be made
    assert_equal original_count, @template.data_records.count
    @existing_record_1.reload

    assert_equal original_name, @existing_record_1.value_for_column(@name_column) # Should be unchanged
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

    assert_equal "John Duplicate", @existing_record_1.value_for_column(@name_column)
    assert_equal "31", @existing_record_1.value_for_column(@age_column)
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
    new_record = @template.data_records.joins(:data_record_values)
                          .joins("JOIN template_columns ON data_record_values.template_column_id = template_columns.id")
                          .where(template_columns: { name: "Name" })
                          .where(data_record_values: { value: "Invalid ID Record" })
                          .first

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

    assert_equal "John Doe", @existing_record_1.value_for_column(@name_column)
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

    assert_equal "John Updated", @existing_record_1.value_for_column(@name_column)

    # Verify new records were created
    new_records = @template.data_records.joins(:data_record_values)
                           .joins("JOIN template_columns ON data_record_values.template_column_id = template_columns.id")
                           .where(template_columns: { name: "Name" })
                           .where(data_record_values: { value: ["New Record 1", "New Record 2"] })

    assert_equal 2, new_records.count
  end

  test "should handle templates with different numbers of columns" do
    # Create a template with only 2 columns
    minimal_template = ImportTemplate.create!(
      name: "Minimal Template",
      description: "Template with fewer columns",
      user: @user
    )

    name_col = minimal_template.template_columns.create!(
      name: "Name",
      data_type: "string",
      column_number: 1,
      required: false
    )

    email_col = minimal_template.template_columns.create!(
      name: "Email",
      data_type: "string",
      column_number: 2,
      required: false
    )

    # Create Excel file with just these 2 columns
    excel_data = [
      ["Name", "Email"],
      ["Alice Johnson", "alice@example.com"],
      ["Bob Wilson", "bob@example.com"]
    ]

    file = create_test_excel_file(excel_data)
    service = ExcelImportService.new(file, minimal_template)
    result = service.process_import

    assert result.success, "Import should succeed with fewer columns"
    assert_equal 2, result.success_count
    assert_equal 0, result.updated_count

    # Verify records were created with correct values
    records = minimal_template.data_records.all

    assert_equal 2, records.count

    alice_record = records.find { |r| r.value_for_column(name_col) == "Alice Johnson" }
    bob_record = records.find { |r| r.value_for_column(name_col) == "Bob Wilson" }

    assert_not_nil alice_record
    assert_not_nil bob_record
    assert_equal "alice@example.com", alice_record.value_for_column(email_col)
    assert_equal "bob@example.com", bob_record.value_for_column(email_col)
  end

  test "should handle templates with many columns" do
    # Create a template with 6 columns (more than the original 5-column limit)
    large_template = ImportTemplate.create!(
      name: "Large Template",
      description: "Template with many columns",
      user: @user
    )

    columns = []
    (1..6).each do |i|
      columns << large_template.template_columns.create!(
        name: "Column #{i}",
        data_type: "string",
        column_number: i,
        required: false
      )
    end

    # Create Excel file with all 6 columns
    excel_data = [
      ["Column 1", "Column 2", "Column 3", "Column 4", "Column 5", "Column 6"],
      ["A1", "A2", "A3", "A4", "A5", "A6"],
      ["B1", "B2", "B3", "B4", "B5", "B6"]
    ]

    file = create_test_excel_file(excel_data)
    service = ExcelImportService.new(file, large_template)
    result = service.process_import

    assert result.success, "Import should succeed with many columns"
    assert_equal 2, result.success_count

    # Verify all column values were imported correctly
    records = large_template.data_records.all

    assert_equal 2, records.count

    record_a = records.find { |r| r.value_for_column(columns[0]) == "A1" }
    record_b = records.find { |r| r.value_for_column(columns[0]) == "B1" }

    assert_not_nil record_a
    assert_not_nil record_b

    # Check all columns for record A
    (0..5).each do |i|
      expected_value = "A#{i + 1}"
      actual_value = record_a.value_for_column(columns[i])

      assert_equal expected_value, actual_value, "Column #{i + 1} should have correct value"
    end

    # Check all columns for record B
    (0..5).each do |i|
      expected_value = "B#{i + 1}"
      actual_value = record_b.value_for_column(columns[i])

      assert_equal expected_value, actual_value, "Column #{i + 1} should have correct value"
    end
  end

  test "should handle required column validation in dynamic system" do
    # Create a template with a required column
    validation_template = ImportTemplate.create!(
      name: "Validation Template",
      user: @user
    )

    validation_template.template_columns.create!(
      name: "Required Field",
      data_type: "string",
      column_number: 1,
      required: true
    )

    validation_template.template_columns.create!(
      name: "Optional Field",
      data_type: "string",
      column_number: 2,
      required: false
    )

    # Create Excel file with missing required field
    excel_data = [
      ["Required Field", "Optional Field"],
      ["", "Optional Value"] # Missing required field
    ]

    file = create_test_excel_file(excel_data)
    service = ExcelImportService.new(file, validation_template)
    result = service.process_import

    assert_not result.success, "Import should fail with missing required field: #{result.errors.join('; ')}"
    assert_predicate result, :has_errors?
  end

  test "should preserve data integrity during partial failures in dynamic system" do
    # Create template with validation that will cause some records to fail
    integrity_template = ImportTemplate.create!(
      name: "Integrity Template",
      user: @user
    )

    integrity_template.template_columns.create!(
      name: "Name",
      data_type: "string",
      column_number: 1,
      required: true
    )

    integrity_template.template_columns.create!(
      name: "Age",
      data_type: "number",
      column_number: 2,
      required: false
    )

    # Create Excel file with mixed valid and invalid data
    excel_data = [
      ["Name", "Age"],
      ["Valid Person", "25"],
      ["", "30"], # Missing required name
      ["Another Valid", "35"]
    ]

    original_count = integrity_template.data_records.count

    file = create_test_excel_file(excel_data)
    service = ExcelImportService.new(file, integrity_template)
    result = service.process_import

    # Import should fail and no records should be created due to transaction rollback
    assert_not result.success, "Import should fail due to validation error: #{result.errors.join('; ')}"

    # Verify no partial data was committed
    assert_equal original_count, integrity_template.data_records.count
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
