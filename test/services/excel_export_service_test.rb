# frozen_string_literal: true

require "test_helper"

class ExcelExportServiceTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @template = ImportTemplate.create!(
      name: "Test Export Template",
      description: "Template for testing exports",
      user: @user,
      column_definitions: {
        "column_1" => { "name" => "Name", "data_type" => "string" },
        "column_2" => { "name" => "Age", "data_type" => "number" },
        "column_3" => { "name" => "Active", "data_type" => "boolean" }
      }
    )

    @template.data_records.create!(
      column_1: "John Doe",
      column_2: "30",
      column_3: "true"
    )

    @template.data_records.create!(
      column_1: "Jane Smith",
      column_2: "25",
      column_3: "false"
    )
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

  test "should handle template with no column definitions" do
    empty_template = ImportTemplate.create!(
      name: "Empty Template",
      user: @user,
      column_definitions: {}
    )

    service = ExcelExportService.new(empty_template)
    package = service.generate_template_file

    # Should still generate a valid Excel file, just with no headers
    assert_not_nil package
  end

  test "should sanitize template name for worksheet" do
    template_with_special_chars = ImportTemplate.create!(
      name: "Test Template! @#$%",
      user: @user,
      column_definitions: {
        "column_1" => { "name" => "Test", "data_type" => "string" }
      }
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
end
