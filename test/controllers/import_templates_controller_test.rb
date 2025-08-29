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

  test "should get import form" do
    get import_form_import_template_url(@import_template)

    assert_response :success
    assert_select "h1", text: "Sync Excel File"
    assert_select "input[type=submit][value='Replace All Data']"
  end

  test "should redirect when no file provided for import" do
    post import_file_import_template_url(@import_template)

    assert_redirected_to import_form_import_template_url(@import_template)
    assert_equal "Please select a file to import.", flash[:alert]
  end

  test "should handle successful sync import with ID column" do
    # Create existing record
    existing_record = @import_template.data_records.create!(column_1: "Original Name")

    # Create Excel file with updated data
    excel_data = [
      ["__record_id", "Name"],
      [existing_record.id, "Updated Name"]
    ]
    
    file = create_test_excel_file(excel_data)

    post import_file_import_template_url(@import_template), params: { excel_file: file }

    assert_redirected_to @import_template
    assert_match(/Successfully synchronized.*updated/, flash[:notice])

    # Verify record was updated
    existing_record.reload
    assert_equal "Updated Name", existing_record.column_1
  end

  test "should handle failed import and show errors" do
    # Create Excel file with invalid data
    excel_data = [
      ["InvalidHeader"],
      ["Some Data"]
    ]
    
    file = create_test_excel_file(excel_data)

    post import_file_import_template_url(@import_template), params: { excel_file: file }

    assert_response :success
    assert_equal "Synchronization failed with errors:", flash.now[:alert]
  end

  private

  def create_test_excel_file(data)
    require "caxlsx"
    
    package = Axlsx::Package.new
    workbook = package.workbook
    
    worksheet = workbook.add_worksheet(name: "Test Data")
    data.each { |row| worksheet.add_row(row) }

    # Create temporary file
    temp_file = Tempfile.new(["controller_test_import", ".xlsx"])
    temp_file.binmode
    temp_file.write(package.to_stream.string)
    temp_file.rewind

    # Create ActionDispatch::Http::UploadedFile-like object
    fixture_file_upload(temp_file.path, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
  end
end
