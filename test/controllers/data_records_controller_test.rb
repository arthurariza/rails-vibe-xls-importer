# frozen_string_literal: true

require "test_helper"

class DataRecordsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @import_template = ImportTemplate.create!(
      name: "Test Template",
      column_definitions: {
        "column_1" => { "name" => "Name", "data_type" => "string" }
      }
    )

    @data_record = @import_template.data_records.create!(
      column_1: "Test Data"
    )
  end

  test "should get index" do
    get data_records_import_template_url(@import_template)

    assert_response :success
  end

  test "should get show" do
    get import_template_data_record_url(@import_template, @data_record)

    assert_response :success
  end

  test "should get new" do
    get new_import_template_data_record_url(@import_template)

    assert_response :success
  end

  test "should get edit" do
    get edit_import_template_data_record_url(@import_template, @data_record)

    assert_response :success
  end
end
