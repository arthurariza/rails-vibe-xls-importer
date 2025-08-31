# frozen_string_literal: true

require "test_helper"

class DataRecordTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @template = ImportTemplate.create!(
      name: "Test Template",
      user: @user,
      column_definitions: {
        "column_1" => { "name" => "Name", "data_type" => "string" },
        "column_2" => { "name" => "Age", "data_type" => "number" },
        "column_3" => { "name" => "Active", "data_type" => "boolean" }
      }
    )
  end

  test "should create data record with valid attributes" do
    record = DataRecord.new(
      import_template: @template,
      column_1: "John Doe",
      column_2: "30",
      column_3: "true"
    )

    assert_predicate record, :valid?
    assert record.save
  end

  test "should require import template" do
    record = DataRecord.new(
      column_1: "Test Data"
    )

    assert_not record.valid?
    assert_includes record.errors[:import_template], "must exist"
  end

  test "should require at least one column with data" do
    record = DataRecord.new(
      import_template: @template
      # No column data provided
    )

    assert_not record.valid?
    assert_includes record.errors[:base], "At least one column must have data"
  end

  test "should allow record with some empty columns" do
    record = DataRecord.new(
      import_template: @template,
      column_1: "John Doe"
      # column_2 and column_3 are empty, which should be allowed
    )

    assert_predicate record, :valid?
  end

  test "column_value should return correct values" do
    record = DataRecord.new(
      column_1: "Test Value",
      column_2: "123",
      column_3: nil
    )

    assert_equal "Test Value", record.column_value(1)
    assert_equal "123", record.column_value(2)
    assert_nil record.column_value(3)
  end

  test "set_column_value should set values correctly" do
    record = DataRecord.new

    record.set_column_value(1, "New Value")
    record.set_column_value(2, "456")

    assert_equal "New Value", record.column_1
    assert_equal "456", record.column_2
  end

  test "column_values should return array of all values" do
    record = DataRecord.new(
      column_1: "A",
      column_2: "B",
      column_3: "C",
      column_4: nil,
      column_5: "E"
    )

    values = record.column_values

    assert_equal ["A", "B", "C", nil, "E"], values
  end

  test "data_hash should return hash with template headers" do
    record = DataRecord.new(
      import_template: @template,
      column_1: "John Doe",
      column_2: "30",
      column_3: "true"
    )

    data_hash = record.data_hash
    expected = {
      "Name" => "John Doe",
      "Age" => "30",
      "Active" => "true"
    }

    assert_equal expected, data_hash
  end

  test "data_hash should skip empty values" do
    record = DataRecord.new(
      import_template: @template,
      column_1: "John Doe",
      column_2: nil,
      column_3: ""
    )

    data_hash = record.data_hash

    assert_equal({ "Name" => "John Doe" }, data_hash)
  end

  test "should handle import_batch_id" do
    batch_id = "batch_123"
    record = DataRecord.create!(
      import_template: @template,
      column_1: "Test Data",
      import_batch_id: batch_id
    )

    assert_equal batch_id, record.import_batch_id
  end

  test "should belong to import template" do
    record = DataRecord.create!(
      import_template: @template,
      column_1: "Test Data"
    )

    assert_equal @template, record.import_template
    assert_includes @template.data_records, record
  end
end
