# frozen_string_literal: true

require "test_helper"

class DataRecordValueTest < ActiveSupport::TestCase
  test "should be valid with valid attributes" do
    data_record_value = data_record_values(:one)

    assert_predicate data_record_value, :valid?
  end

  test "should require data_record" do
    data_record_value = DataRecordValue.new(
      template_column: template_columns(:one),
      value: "test value"
    )

    assert_not data_record_value.valid?
    assert_includes data_record_value.errors[:data_record], "must exist"
  end

  test "should require template_column" do
    data_record_value = DataRecordValue.new(
      data_record: data_records(:one),
      value: "test value"
    )

    assert_not data_record_value.valid?
    assert_includes data_record_value.errors[:template_column], "must exist"
  end

  test "should belong to data_record" do
    data_record_value = data_record_values(:one)

    assert_equal data_records(:one), data_record_value.data_record
    assert_respond_to data_record_value, :data_record
  end

  test "should belong to template_column" do
    data_record_value = data_record_values(:one)

    assert_equal template_columns(:one), data_record_value.template_column
    assert_respond_to data_record_value, :template_column
  end

  test "should allow empty values" do
    data_record_value = DataRecordValue.new(
      data_record: data_records(:one),
      template_column: template_columns(:email), # Use the email column we added to avoid conflict
      value: nil
    )

    assert_predicate data_record_value, :valid?

    data_record_value.value = ""

    assert_predicate data_record_value, :valid?
  end

  test "should store string values" do
    data_record_value = data_record_values(:one)
    data_record_value.value = "Test String Value"

    assert data_record_value.save
    assert_equal "Test String Value", data_record_value.reload.value
  end

  test "should store number values as strings" do
    data_record_value = data_record_values(:two)
    data_record_value.value = "123.45"

    assert data_record_value.save
    assert_equal "123.45", data_record_value.reload.value
  end

  test "should store boolean values as strings" do
    data_record_value = data_record_values(:one)
    data_record_value.value = "true"

    assert data_record_value.save
    assert_equal "true", data_record_value.reload.value

    data_record_value.value = "false"

    assert data_record_value.save
    assert_equal "false", data_record_value.reload.value
  end

  test "should store date values as strings" do
    data_record_value = data_record_values(:one)
    data_record_value.value = "2023-12-25"

    assert data_record_value.save
    assert_equal "2023-12-25", data_record_value.reload.value
  end

  test "should validate uniqueness of template_column per data_record" do
    # Use template 2 and its records to avoid cross-template conflicts
    data_record = data_records(:two)
    template_column = template_columns(:three) # Belongs to same template as data_record

    # First value should be valid (but this combination already exists in fixtures, so create a new record)
    new_data_record = DataRecord.create!(import_template: import_templates(:two))
    
    DataRecordValue.create!(
      data_record: new_data_record,
      template_column: template_column,
      value: "first value"
    )

    # Second value with same data_record and template_column should not be valid
    value2 = DataRecordValue.new(
      data_record: new_data_record,
      template_column: template_column,
      value: "second value"
    )

    assert_not value2.valid?
    assert_includes value2.errors[:data_record_id], "has already been taken"

    # But same template_column with different data_record should be valid
    another_data_record = DataRecord.create!(import_template: import_templates(:two))
    value3 = DataRecordValue.new(
      data_record: another_data_record,
      template_column: template_column,
      value: "third value"
    )

    assert_predicate value3, :valid?
  end

  test "should handle long text values" do
    data_record_value = data_record_values(:one)
    long_text = "A" * 1000
    data_record_value.value = long_text

    assert data_record_value.save
    assert_equal long_text, data_record_value.reload.value
  end

  test "should maintain referential integrity" do
    data_record_value = data_record_values(:one)
    original_data_record = data_record_value.data_record
    original_template_column = data_record_value.template_column

    # Destroying the data_record should destroy its values (data_record :one has 2 values in fixtures)
    assert_difference "DataRecordValue.count", -2 do
      original_data_record.destroy!
    end

    # Create a new value to test template_column destruction
    DataRecordValue.create!(
      data_record: data_records(:two),
      template_column: original_template_column,
      value: "test"
    )

    # Destroying the template_column should destroy the value
    assert_difference "DataRecordValue.count", -1 do
      original_template_column.destroy!
    end
  end

  test "should be created with nested attributes through data_record" do
    data_record = data_records(:one)
    template_column = template_columns(:one)

    # Remove existing value if any
    data_record.data_record_values.where(template_column: template_column).destroy_all

    attributes = {
      data_record_values_attributes: [
        {
          template_column_id: template_column.id,
          value: "Nested attribute value"
        }
      ]
    }

    assert_difference "DataRecordValue.count", 1 do
      data_record.update!(attributes)
    end

    created_value = data_record.data_record_values.find_by(template_column: template_column)

    assert_equal "Nested attribute value", created_value.value
  end
end
