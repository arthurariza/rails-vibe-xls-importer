# frozen_string_literal: true

require "test_helper"

class TemplateColumnTest < ActiveSupport::TestCase
  test "should be valid with valid attributes" do
    template_column = template_columns(:one)

    assert_predicate template_column, :valid?
  end

  test "should require import_template" do
    template_column = TemplateColumn.new(
      column_number: 1,
      name: "Test Column",
      data_type: "string",
      required: false
    )

    assert_not template_column.valid?
    assert_includes template_column.errors[:import_template], "must exist"
  end

  test "should require name" do
    template_column = template_columns(:one)
    template_column.name = nil

    assert_not template_column.valid?
    assert_includes template_column.errors[:name], "can't be blank"

    template_column.name = ""

    assert_not template_column.valid?
    assert_includes template_column.errors[:name], "can't be blank"
  end

  test "should require column_number" do
    template_column = template_columns(:one)
    template_column.column_number = nil

    assert_not template_column.valid?
    assert_includes template_column.errors[:column_number], "can't be blank"
  end

  test "should require data_type" do
    template_column = template_columns(:one)
    template_column.data_type = nil

    assert_not template_column.valid?
    assert_includes template_column.errors[:data_type], "can't be blank"
  end

  test "should validate data_type inclusion" do
    template_column = template_columns(:one)

    %w[string number date boolean].each do |valid_type|
      template_column.data_type = valid_type

      assert_predicate template_column, :valid?, "#{valid_type} should be a valid data type"
    end

    template_column.data_type = "invalid_type"

    assert_not template_column.valid?
    assert_includes template_column.errors[:data_type], "is not included in the list"
  end

  test "should validate column_number uniqueness within template" do
    template = import_templates(:one)

    # Create first column
    TemplateColumn.create!(
      import_template: template,
      column_number: 5,
      name: "First Column",
      data_type: "string",
      required: false
    )

    # Try to create another column with same number in same template
    column2 = TemplateColumn.new(
      import_template: template,
      column_number: 5,
      name: "Second Column",
      data_type: "string",
      required: false
    )

    assert_not column2.valid?
    assert_includes column2.errors[:column_number], "has already been taken"

    # But should allow same column number in different template
    column3 = TemplateColumn.new(
      import_template: import_templates(:two),
      column_number: 5,
      name: "Third Column",
      data_type: "string",
      required: false
    )

    assert_predicate column3, :valid?
  end

  test "should belong to import_template" do
    template_column = template_columns(:one)

    assert_equal import_templates(:one), template_column.import_template
  end

  test "should have many data_record_values" do
    template_column = template_columns(:one)

    assert_respond_to template_column, :data_record_values
  end

  test "ordered scope should return columns ordered by column_number" do
    template = ImportTemplate.create!(name: "Ordered Test Template", user: users(:one))

    # Create columns out of order
    TemplateColumn.create!(
      import_template: template,
      column_number: 3,
      name: "Third",
      data_type: "string",
      required: false
    )

    TemplateColumn.create!(
      import_template: template,
      column_number: 1,
      name: "First",
      data_type: "string",
      required: false
    )

    TemplateColumn.create!(
      import_template: template,
      column_number: 2,
      name: "Second",
      data_type: "string",
      required: false
    )

    ordered_columns = template.template_columns.ordered

    assert_equal [1, 2, 3], ordered_columns.pluck(:column_number)
    assert_equal %w[First Second Third], ordered_columns.pluck(:name)
  end

  test "should have required boolean attribute" do
    template_column = template_columns(:one)

    assert_respond_to template_column, :required?
    assert_includes [true, false], template_column.required?
  end

  test "should destroy dependent data_record_values when destroyed" do
    template_column = template_columns(:email) # Use email column which has no existing values
    data_record = data_records(:two)

    # Create a data_record_value
    DataRecordValue.create!(
      data_record: data_record,
      template_column: template_column,
      value: "test value"
    )

    assert_difference "DataRecordValue.count", -1 do
      template_column.destroy!
    end
  end
end
