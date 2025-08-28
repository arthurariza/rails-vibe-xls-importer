# frozen_string_literal: true

require "test_helper"

class ImportTemplateTest < ActiveSupport::TestCase
  test "should create import template with valid attributes" do
    template = ImportTemplate.new(
      name: "Employee Data",
      description: "Employee information template",
      column_definitions: {
        "column_1" => { "name" => "Name", "data_type" => "string" },
        "column_2" => { "name" => "Age", "data_type" => "number" },
        "column_3" => { "name" => "Start Date", "data_type" => "date" }
      }
    )

    assert_predicate template, :valid?
    assert template.save
  end

  test "should require name" do
    template = ImportTemplate.new(
      description: "Test template",
      column_definitions: {}
    )

    assert_not template.valid?
    assert_includes template.errors[:name], "can't be blank"
  end

  test "should require unique name" do
    # Create first template
    ImportTemplate.create!(
      name: "Duplicate Name",
      column_definitions: {}
    )

    # Try to create second template with same name
    template = ImportTemplate.new(
      name: "Duplicate Name",
      column_definitions: {}
    )

    assert_not template.valid?
    assert_includes template.errors[:name], "has already been taken"
  end

  test "should validate column definitions structure" do
    template = ImportTemplate.new(
      name: "Invalid Columns",
      column_definitions: {
        "column_1" => { "name" => "Valid Column", "data_type" => "string" },
        "column_2" => { "name" => "", "data_type" => "string" } # Invalid: empty name
      }
    )

    assert_not template.valid?
    assert_includes template.errors[:column_definitions], "column 2 must have a name"
  end

  test "should validate data types" do
    template = ImportTemplate.new(
      name: "Invalid Data Types",
      column_definitions: {
        "column_1" => { "name" => "Invalid Type", "data_type" => "invalid_type" }
      }
    )

    assert_not template.valid?
    assert_includes template.errors[:column_definitions],
                    "column 1 must have a valid data_type (string, number, date, boolean)"
  end

  test "should return column headers in order" do
    template = ImportTemplate.new(
      column_definitions: {
        "column_1" => { "name" => "First", "data_type" => "string" },
        "column_2" => { "name" => "Second", "data_type" => "number" },
        "column_5" => { "name" => "Fifth", "data_type" => "boolean" }
      }
    )

    headers = template.column_headers

    assert_equal %w[First Second Fifth], headers
  end

  test "should return column definition by number" do
    template = ImportTemplate.new(
      column_definitions: {
        "column_1" => { "name" => "Test Column", "data_type" => "string" }
      }
    )

    column_def = template.column_definition(1)

    assert_equal "Test Column", column_def["name"]
    assert_equal "string", column_def["data_type"]

    # Non-existent column should return nil
    assert_nil template.column_definition(5)
  end

  test "should allow empty column definitions" do
    template = ImportTemplate.new(
      name: "Minimal Template",
      column_definitions: {}
    )

    assert_predicate template, :valid?
    assert_empty template.column_headers
  end
end
