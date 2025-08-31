# frozen_string_literal: true

require "test_helper"

class ExcelExportServiceTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @template = ImportTemplate.create!(
      name: "Test Export Template",
      description: "Template for testing exports",
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

    # Create test data records using the new dynamic system
    record1 = @template.data_records.create!
    record1.set_value_for_column(@name_column, "John Doe")
    record1.set_value_for_column(@age_column, "30")
    record1.set_value_for_column(@active_column, "true")

    record2 = @template.data_records.create!
    record2.set_value_for_column(@name_column, "Jane Smith")
    record2.set_value_for_column(@age_column, "25")
    record2.set_value_for_column(@active_column, "false")
  end

  test "should generate template file with headers only" do
    service = ExcelExportService.new(@template)
    package = service.generate_template_file

    assert_not_nil package
    assert_respond_to package, :to_stream

    # Verify we can read the stream
    stream = package.to_stream

    assert_operator stream.size, :>, 0
  end

  test "should generate data file with records" do
    service = ExcelExportService.new(@template)
    package = service.generate_data_file

    assert_not_nil package

    # Should include both headers and data
    stream = package.to_stream

    assert_operator stream.size, :>, 0
  end

  test "should generate sample file with placeholder data" do
    service = ExcelExportService.new(@template)
    package = service.generate_sample_file

    assert_not_nil package

    stream = package.to_stream

    assert_operator stream.size, :>, 0
  end

  test "should handle template with no template columns" do
    empty_template = ImportTemplate.create!(
      name: "Empty Template",
      user: @user
    )
    # No template_columns are created for this template

    service = ExcelExportService.new(empty_template)
    package = service.generate_template_file

    # Should still generate a valid Excel file, just with no headers
    assert_not_nil package
  end

  test "should sanitize template name for worksheet" do
    template_with_special_chars = ImportTemplate.create!(
      name: "Test Template! @#$%",
      user: @user
    )

    # Create a test column
    template_with_special_chars.template_columns.create!(
      name: "Test",
      data_type: "string",
      column_number: 1,
      required: false
    )

    service = ExcelExportService.new(template_with_special_chars)
    package = service.generate_template_file

    # Should not raise error despite special characters in name
    assert_not_nil package
  end

  test "should include ID column as first column in data exports" do
    service = ExcelExportService.new(@template)
    package = service.generate_data_file

    # Write to temporary file and read back to verify content
    temp_file = Tempfile.new(["test_export", ".xlsx"])
    temp_file.binmode
    temp_file.write(package.to_stream.string)
    temp_file.close

    # Read back the Excel file to verify structure
    require "roo"
    workbook = Roo::Excelx.new(temp_file.path)

    # Check headers - first should be __record_id
    headers = workbook.row(1)

    assert_equal "__record_id", headers[0]
    assert_equal "Name", headers[1]
    assert_equal "Age", headers[2]
    assert_equal "Active", headers[3]

    # Check first data row has actual record ID
    first_data_row = workbook.row(2)
    first_record_id = @template.data_records.first.id

    assert_equal first_record_id, first_data_row[0].to_i
    assert_equal "John Doe", first_data_row[1]

    temp_file.unlink
  end

  test "should include empty ID column in template exports" do
    service = ExcelExportService.new(@template)
    package = service.generate_template_file

    # Write to temporary file and read back to verify content
    temp_file = Tempfile.new(["test_template_export", ".xlsx"])
    temp_file.binmode
    temp_file.write(package.to_stream.string)
    temp_file.close

    # Read back the Excel file to verify structure
    require "roo"
    workbook = Roo::Excelx.new(temp_file.path)

    # Check headers - first should be __record_id
    headers = workbook.row(1)

    assert_equal "__record_id", headers[0]
    assert_equal "Name", headers[1]

    # Should only have header row, no data rows
    assert_equal 1, workbook.last_row

    temp_file.unlink
  end

  test "should include empty ID column in sample exports" do
    service = ExcelExportService.new(@template)
    package = service.generate_sample_file

    # Write to temporary file and read back to verify content
    temp_file = Tempfile.new(["test_sample_export", ".xlsx"])
    temp_file.binmode
    temp_file.write(package.to_stream.string)
    temp_file.close

    # Read back the Excel file to verify structure
    require "roo"
    workbook = Roo::Excelx.new(temp_file.path)

    # Check headers - first should be __record_id
    headers = workbook.row(1)

    assert_equal "__record_id", headers[0]

    # Check sample data rows have empty ID values
    (2..4).each do |row_num|
      sample_row = workbook.row(row_num)
      # ID column should be empty for samples (nil or empty string)
      assert_predicate sample_row[0], :blank?, "ID column should be empty for sample data"
    end

    temp_file.unlink
  end

  test "should export templates with different numbers of columns" do
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

    # Create a test record with all columns
    record = large_template.data_records.create!
    columns.each_with_index do |column, index|
      record.set_value_for_column(column, "Value #{index + 1}")
    end

    service = ExcelExportService.new(large_template)
    package = service.generate_data_file

    # Write to temporary file and read back to verify all columns are exported
    temp_file = Tempfile.new(["test_large_export", ".xlsx"])
    temp_file.binmode
    temp_file.write(package.to_stream.string)
    temp_file.close

    # Read back the Excel file to verify structure
    require "roo"
    workbook = Roo::Excelx.new(temp_file.path)

    # Check headers - should have __record_id + 6 columns
    headers = workbook.row(1)

    assert_equal "__record_id", headers[0]
    (1..6).each do |i|
      assert_equal "Column #{i}", headers[i]
    end

    # Check data row has all values
    data_row = workbook.row(2)

    assert_equal record.id, data_row[0].to_i
    (1..6).each do |i|
      assert_equal "Value #{i}", data_row[i]
    end

    temp_file.unlink
  end

  test "should export templates with minimal columns" do
    # Create a template with only 2 columns
    minimal_template = ImportTemplate.create!(
      name: "Minimal Template",
      description: "Template with few columns",
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

    # Create test records
    record1 = minimal_template.data_records.create!
    record1.set_value_for_column(name_col, "Alice Johnson")
    record1.set_value_for_column(email_col, "alice@example.com")

    record2 = minimal_template.data_records.create!
    record2.set_value_for_column(name_col, "Bob Wilson")
    record2.set_value_for_column(email_col, "bob@example.com")

    service = ExcelExportService.new(minimal_template)
    package = service.generate_data_file

    # Write to temporary file and read back to verify content
    temp_file = Tempfile.new(["test_minimal_export", ".xlsx"])
    temp_file.binmode
    temp_file.write(package.to_stream.string)
    temp_file.close

    # Read back the Excel file to verify structure
    require "roo"
    workbook = Roo::Excelx.new(temp_file.path)

    # Check headers
    headers = workbook.row(1)

    assert_equal "__record_id", headers[0]
    assert_equal "Name", headers[1]
    assert_equal "Email", headers[2]

    # Check that we only have the expected columns (no extra columns)
    assert_equal 3, headers.length

    # Check data rows
    first_row = workbook.row(2)

    assert_equal "Alice Johnson", first_row[1]
    assert_equal "alice@example.com", first_row[2]

    second_row = workbook.row(3)

    assert_equal "Bob Wilson", second_row[1]
    assert_equal "bob@example.com", second_row[2]

    temp_file.unlink
  end

  test "should handle different data types in exports" do
    # Create a template with various data types
    types_template = ImportTemplate.create!(
      name: "Data Types Template",
      user: @user
    )

    string_col = types_template.template_columns.create!(
      name: "Text Field",
      data_type: "string",
      column_number: 1,
      required: false
    )

    number_col = types_template.template_columns.create!(
      name: "Number Field",
      data_type: "number",
      column_number: 2,
      required: false
    )

    date_col = types_template.template_columns.create!(
      name: "Date Field",
      data_type: "date",
      column_number: 3,
      required: false
    )

    boolean_col = types_template.template_columns.create!(
      name: "Boolean Field",
      data_type: "boolean",
      column_number: 4,
      required: false
    )

    # Create test record with different data types
    record = types_template.data_records.create!
    record.set_value_for_column(string_col, "Sample Text")
    record.set_value_for_column(number_col, "123.45")
    record.set_value_for_column(date_col, "2024-01-15")
    record.set_value_for_column(boolean_col, "true")

    service = ExcelExportService.new(types_template)
    package = service.generate_data_file

    # Write to temporary file and read back to verify content
    temp_file = Tempfile.new(["test_types_export", ".xlsx"])
    temp_file.binmode
    temp_file.write(package.to_stream.string)
    temp_file.close

    # Read back the Excel file to verify structure
    require "roo"
    workbook = Roo::Excelx.new(temp_file.path)

    # Check headers
    headers = workbook.row(1)

    assert_equal "Text Field", headers[1]
    assert_equal "Number Field", headers[2]
    assert_equal "Date Field", headers[3]
    assert_equal "Boolean Field", headers[4]

    # Check data values are exported correctly
    data_row = workbook.row(2)

    assert_equal "Sample Text", data_row[1]
    assert_equal "123.45", data_row[2].to_s
    # Date may be returned as Date object, so check the date value or string representation
    date_value = data_row[3]

    assert(date_value.to_s.include?("2024") && date_value.to_s.include?("15"), "Date should contain 2024 and 15")
    # Boolean may be returned as boolean or string, check the actual value
    boolean_value = data_row[4]

    assert_includes([true, "true"], boolean_value, "Boolean should be true or 'true'")

    temp_file.unlink
  end

  test "should generate sample data for different column counts" do
    # Create a template with custom column configuration
    sample_template = ImportTemplate.create!(
      name: "Sample Template",
      user: @user
    )

    # Create 4 columns of different types
    sample_template.template_columns.create!(
      name: "Product Name",
      data_type: "string",
      column_number: 1,
      required: true
    )

    sample_template.template_columns.create!(
      name: "Price",
      data_type: "number",
      column_number: 2,
      required: false
    )

    sample_template.template_columns.create!(
      name: "Launch Date",
      data_type: "date",
      column_number: 3,
      required: false
    )

    sample_template.template_columns.create!(
      name: "In Stock",
      data_type: "boolean",
      column_number: 4,
      required: false
    )

    service = ExcelExportService.new(sample_template)
    package = service.generate_sample_file

    # Write to temporary file and read back to verify content
    temp_file = Tempfile.new(["test_dynamic_sample", ".xlsx"])
    temp_file.binmode
    temp_file.write(package.to_stream.string)
    temp_file.close

    # Read back the Excel file to verify structure
    require "roo"
    workbook = Roo::Excelx.new(temp_file.path)

    # Check headers
    headers = workbook.row(1)

    assert_equal "__record_id", headers[0]
    assert_equal "Product Name", headers[1]
    assert_equal "Price", headers[2]
    assert_equal "Launch Date", headers[3]
    assert_equal "In Stock", headers[4]

    # Check that sample data was generated (should have multiple rows)
    assert_operator workbook.last_row, :>, 1, "Sample file should contain sample data rows"

    # Check that ID columns in sample data are empty
    (2..workbook.last_row).each do |row_num|
      sample_row = workbook.row(row_num)

      assert_predicate sample_row[0], :blank?, "ID column should be empty in sample data"
    end

    temp_file.unlink
  end
end
