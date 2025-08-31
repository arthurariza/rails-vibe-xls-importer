# frozen_string_literal: true

require "test_helper"

class TemplateColumnsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  
  setup do
    @user = users(:one)
    @template = import_templates(:one)
    @template_column = template_columns(:one)
    sign_in @user
  end

  test "should create template column" do
    assert_difference "TemplateColumn.count" do
      post import_template_template_columns_path(@template), params: {
        template_column: {
          name: "New Column",
          data_type: "string",
          required: false
        }
      }, headers: { "Accept" => "application/json" }
    end

    assert_response :created
    json_response = response.parsed_body

    assert_equal "New Column", json_response["name"]
    assert_equal "string", json_response["data_type"]
  end

  test "should not create template column with invalid attributes" do
    assert_no_difference "TemplateColumn.count" do
      post import_template_template_columns_path(@template), params: {
        template_column: {
          name: "", # Invalid: empty name
          data_type: "string",
          required: false
        }
      }, headers: { "Accept" => "application/json" }
    end

    assert_response :unprocessable_content
    json_response = response.parsed_body

    assert_includes json_response["errors"]["name"], "can't be blank"
  end

  test "should not create template column with invalid data type" do
    assert_no_difference "TemplateColumn.count" do
      post import_template_template_columns_path(@template), params: {
        template_column: {
          name: "Invalid Column",
          data_type: "invalid_type", # Invalid data type
          required: false
        }
      }, headers: { "Accept" => "application/json" }
    end

    assert_response :unprocessable_content
    json_response = response.parsed_body

    assert_includes json_response["errors"]["data_type"], "is not included in the list"
  end

  test "should update template column" do
    patch import_template_template_column_path(@template, @template_column), params: {
      template_column: {
        name: "Updated Column Name",
        data_type: "number",
        required: true
      }
    }, headers: { "Accept" => "application/json" }

    assert_response :success
    json_response = response.parsed_body

    assert_equal "Updated Column Name", json_response["name"]
    assert_equal "number", json_response["data_type"]
    assert json_response["required"]

    @template_column.reload

    assert_equal "Updated Column Name", @template_column.name
    assert_equal "number", @template_column.data_type
    assert @template_column.required
  end

  test "should not update template column with invalid attributes" do
    original_name = @template_column.name

    patch import_template_template_column_path(@template, @template_column), params: {
      template_column: {
        name: "", # Invalid: empty name
        data_type: "string"
      }
    }, headers: { "Accept" => "application/json" }

    assert_response :unprocessable_content
    json_response = response.parsed_body

    assert_includes json_response["errors"]["name"], "can't be blank"

    @template_column.reload

    assert_equal original_name, @template_column.name
  end

  test "should destroy template column" do
    assert_difference "TemplateColumn.count", -1 do
      delete import_template_template_column_path(@template, @template_column),
             headers: { "Accept" => "application/json" }
    end

    assert_response :no_content
  end

  test "should destroy associated data_record_values when destroying template column" do
    # Create a new template column to avoid fixture conflicts
    test_column = @template.template_columns.create!(
      name: "Test Column",
      data_type: "string",
      required: false
    )
    
    # Create a data record with values
    data_record = @template.data_records.create!
    data_record.data_record_values.create!(
      template_column: test_column,
      value: "test value"
    )

    assert_difference "DataRecordValue.count", -1 do
      delete import_template_template_column_path(@template, test_column),
             headers: { "Accept" => "application/json" }
    end

    assert_response :no_content
  end

  test "should assign sequential column numbers" do
    # Create columns and check they get sequential numbers
    post import_template_template_columns_path(@template), params: {
      template_column: {
        name: "Column A",
        data_type: "string",
        required: false
      }
    }, headers: { "Accept" => "application/json" }

    first_column = response.parsed_body

    post import_template_template_columns_path(@template), params: {
      template_column: {
        name: "Column B",
        data_type: "string",
        required: false
      }
    }, headers: { "Accept" => "application/json" }

    second_column = response.parsed_body

    assert_operator second_column["column_number"], :>, first_column["column_number"]
  end

  test "should not allow access to other users templates" do
    other_template = ImportTemplate.create!(
      name: "Other Template",
      user: users(:two)
    )

    post import_template_template_columns_path(other_template), params: {
      template_column: {
        name: "Unauthorized Column",
        data_type: "string",
        required: false
      }
    }, headers: { "Accept" => "application/json" }

    assert_response :not_found
  end

  test "should reorder columns after deletion" do
    # Create multiple columns
    col1 = @template.template_columns.create!(name: "Col1", data_type: "string", required: false)
    column2 = @template.template_columns.create!(name: "Col2", data_type: "string", required: false)
    col3 = @template.template_columns.create!(name: "Col3", data_type: "string", required: false)

    # Delete the middle column
    delete import_template_template_column_path(@template, column2),
           headers: { "Accept" => "application/json" }

    assert_response :no_content

    # Check that remaining columns are reordered
    @template.reload
    remaining_columns = @template.template_columns.ordered
    column_numbers = remaining_columns.pluck(:column_number)

    # Should be sequential after reordering
    assert_equal column_numbers.sort, column_numbers
  end

  test "should return appropriate JSON responses" do
    # Test successful creation
    post import_template_template_columns_path(@template), params: {
      template_column: {
        name: "JSON Test Column",
        data_type: "boolean",
        required: true
      }
    }, headers: { "Accept" => "application/json" }

    assert_response :created
    assert_equal "application/json", response.media_type

    json_response = response.parsed_body

    assert json_response.key?("id")
    assert json_response.key?("name")
    assert json_response.key?("data_type")
    assert json_response.key?("required")
    assert json_response.key?("column_number")
    assert json_response.key?("created_at")
    assert json_response.key?("updated_at")
  end
end
