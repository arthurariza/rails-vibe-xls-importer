# frozen_string_literal: true

require "test_helper"

class ImportTemplatesControllerTest < ActionDispatch::IntegrationTest
  def setup
    @import_template = ImportTemplate.create!(
      name: "Test Template",
      column_definitions: {
        "column_1" => { "name" => "Name", "data_type" => "string" }
      }
    )
  end

  test "should get index" do
    get import_templates_url

    assert_response :success
  end

  test "should get show" do
    get import_template_url(@import_template)

    assert_response :success
  end

  test "should get new" do
    get new_import_template_url

    assert_response :success
  end

  test "should get edit" do
    get edit_import_template_url(@import_template)

    assert_response :success
  end

  test "should export template" do
    get export_template_import_template_url(@import_template)

    assert_response :success
    assert_equal "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", response.content_type
  end
end
