# frozen_string_literal: true

require "test_helper"

class DataRecordsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def setup
    @user = users(:one)
    @import_template = ImportTemplate.create!(
      name: "Test Template",
      user: @user,
      column_definitions: {
        "column_1" => { "name" => "Name", "data_type" => "string" }
      }
    )

    @data_record = @import_template.data_records.create!(
      column_1: "Test Data"
    )
    sign_in @user
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

  test "should redirect to login when not authenticated" do
    sign_out @user

    get data_records_import_template_url(@import_template)

    assert_redirected_to new_user_session_url
  end

  test "should not allow access to other user's data records" do
    other_user = users(:two)
    other_template = ImportTemplate.create!(
      name: "Other User Template",
      user: other_user,
      column_definitions: {
        "column_1" => { "name" => "Other", "data_type" => "string" }
      }
    )
    other_template.data_records.create!(column_1: "Other Data")

    get data_records_import_template_url(other_template)

    assert_redirected_to root_path
    assert_equal "You don't have permission to access that resource.", flash[:alert]
  end

  test "should not allow access to specific data record from other user's template" do
    other_user = users(:two)
    other_template = ImportTemplate.create!(
      name: "Other User Template",
      user: other_user,
      column_definitions: {
        "column_1" => { "name" => "Other", "data_type" => "string" }
      }
    )
    other_record = other_template.data_records.create!(column_1: "Other Data")

    get import_template_data_record_url(other_template, other_record)

    assert_redirected_to root_path
    assert_equal "You don't have permission to access that resource.", flash[:alert]
  end

  test "should not allow editing data record from other user's template" do
    other_user = users(:two)
    other_template = ImportTemplate.create!(
      name: "Other User Template",
      user: other_user,
      column_definitions: {
        "column_1" => { "name" => "Other", "data_type" => "string" }
      }
    )
    other_record = other_template.data_records.create!(column_1: "Other Data")

    get edit_import_template_data_record_url(other_template, other_record)

    assert_redirected_to root_path
    assert_equal "You don't have permission to access that resource.", flash[:alert]
  end

  test "should only show data records for user's own template" do
    other_user = users(:two)
    other_template = ImportTemplate.create!(
      name: "Other User Template",
      user: other_user,
      column_definitions: {
        "column_1" => { "name" => "Other", "data_type" => "string" }
      }
    )
    other_record = other_template.data_records.create!(column_1: "Other Data")

    get data_records_import_template_url(@import_template)

    assert_response :success
    assert_select "td", text: @data_record.column_1
    assert_select "td", text: other_record.column_1, count: 0
  end
end
