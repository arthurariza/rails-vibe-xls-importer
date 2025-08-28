require "test_helper"

class ImportTemplatesControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get import_templates_index_url

    assert_response :success
  end

  test "should get show" do
    get import_templates_show_url

    assert_response :success
  end

  test "should get new" do
    get import_templates_new_url

    assert_response :success
  end

  test "should get create" do
    get import_templates_create_url

    assert_response :success
  end

  test "should get edit" do
    get import_templates_edit_url

    assert_response :success
  end

  test "should get update" do
    get import_templates_update_url

    assert_response :success
  end

  test "should get destroy" do
    get import_templates_destroy_url

    assert_response :success
  end
end
