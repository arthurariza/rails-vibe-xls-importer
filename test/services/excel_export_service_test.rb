# frozen_string_literal: true

require "test_helper"

class ExcelExportServiceTest < ActiveSupport::TestCase
  def setup
    @template = ImportTemplate.create!(
      name: "Test Export Template",
      description: "Template for testing exports",
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
      column_definitions: {
        "column_1" => { "name" => "Test", "data_type" => "string" }
      }
    )

    service = ExcelExportService.new(template_with_special_chars)
    package = service.generate_template_file

    # Should not raise error despite special characters in name
    assert_not_nil package
  end
end
