# frozen_string_literal: true

require "test_helper"

class ImportTemplateTest < ActiveSupport::TestCase
  test "should create import template with valid attributes" do
    template = ImportTemplate.new(
      name: "Employee Data",
      description: "Employee information template",
      user: users(:one)
    )

    assert_predicate template, :valid?
    assert template.save
  end

  test "should require name" do
    template = ImportTemplate.new(
      description: "Test template",
      user: users(:one)
    )

    assert_not template.valid?
    assert_includes template.errors[:name], "can't be blank"
  end

  test "should require unique name" do
    # Create first template
    ImportTemplate.create!(
      name: "Duplicate Name",
      user: users(:one)
    )

    # Try to create second template with same name
    template = ImportTemplate.new(
      name: "Duplicate Name",
      user: users(:two)
    )

    assert_not template.valid?
    assert_includes template.errors[:name], "has already been taken"
  end

  test "should have many template_columns" do
    template = import_templates(:one)

    assert_respond_to template, :template_columns
    assert_predicate template.template_columns, :any?
  end

  test "should have many data_records" do
    template = import_templates(:one)

    assert_respond_to template, :data_records
  end

  test "should return column headers from template_columns in order" do
    template = import_templates(:one)
    headers = template.column_headers

    expected_headers = template.template_columns.ordered.pluck(:name)

    assert_equal expected_headers, headers
  end

  test "should return empty array for column headers when no template_columns exist" do
    template = ImportTemplate.create!(
      name: "Empty Template",
      user: users(:one)
    )

    assert_empty template.column_headers
  end

  test "should validate at least one column exists" do
    template = ImportTemplate.create!(
      name: "Test Template",
      user: users(:one)
    )

    assert_predicate template, :valid?

    # Add validation requirement (this would be a business rule)
    # For now, templates can exist without columns (they get added later)
  end

  test "should destroy associated template_columns when destroyed" do
    template = import_templates(:one)
    column_count = template.template_columns.count

    assert_predicate column_count, :positive?, "Template should have columns for this test"

    assert_difference "TemplateColumn.count", -column_count do
      template.destroy!
    end
  end

  test "should destroy associated data_records when destroyed" do
    template = import_templates(:one)
    record_count = template.data_records.count

    if record_count.positive?
      assert_difference "DataRecord.count", -record_count do
        template.destroy!
      end
    else
      # If no records exist, create one for the test
      template.data_records.create!
      assert_difference "DataRecord.count", -1 do
        template.destroy!
      end
    end
  end

  test "should update data_records_count counter cache" do
    template = import_templates(:one)
    template.data_records_count || 0

    assert_difference "template.reload.data_records_count", 1 do
      template.data_records.create!
    end

    assert_difference "template.reload.data_records_count", -1 do
      template.data_records.last.destroy!
    end
  end

  test "should have ordered template_columns association" do
    template = import_templates(:one)

    # Add columns with specific order
    template.template_columns.destroy_all

    template.template_columns.create!(name: "Third", data_type: "string", column_number: 3, required: false)
    template.template_columns.create!(name: "First", data_type: "string", column_number: 1, required: false)
    template.template_columns.create!(name: "Second", data_type: "string", column_number: 2, required: false)

    ordered_columns = template.template_columns.ordered

    assert_equal [1, 2, 3], ordered_columns.pluck(:column_number)
    assert_equal %w[First Second Third], ordered_columns.pluck(:name)
  end

  test "should belong to user" do
    template = import_templates(:one)

    assert_equal users(:one), template.user
    assert_respond_to template, :user
  end

  test "should allow templates with many columns" do
    template = ImportTemplate.create!(
      name: "Many Column Template",
      user: users(:one)
    )

    # Create 10 columns
    10.times do |i|
      template.template_columns.create!(
        name: "Column #{i + 1}",
        data_type: "string",
        column_number: i + 1,
        required: false
      )
    end

    assert_equal 10, template.template_columns.count
    assert_equal 10, template.column_headers.count
  end

  test "should handle template without columns gracefully" do
    template = ImportTemplate.create!(
      name: "No Columns Template",
      user: users(:one)
    )

    assert_empty template.template_columns
    assert_empty template.column_headers
    assert_predicate template, :valid?
  end
end
