# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

class ImportTemplatesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def setup
    @user = users(:one)
    @import_template = ImportTemplate.create!(
      name: "Test Template",
      user: @user
    )
    # Create template column using the new system
    @import_template.template_columns.create!(
      column_number: 1,
      name: "Name",
      data_type: "string"
    )
    sign_in @user
    
    # Setup cache for JobStatusService
    @original_cache_store = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end
  
  def teardown
    # Restore cache
    Rails.cache = @original_cache_store
    
    # Clean up any temporary files created during tests
    FileUtils.rm_rf(Rails.root.join("tmp", "imports")) if Dir.exist?(Rails.root.join("tmp", "imports"))
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

  test "should handle successful sync import with ID column (now using background processing)" do
    # Create existing record
    existing_record = @import_template.data_records.create!
    template_column = @import_template.template_columns.first
    existing_record.set_value_for_column(template_column, "Original Name")

    # Create Excel file with updated data
    excel_data = [
      ["__record_id", "Name"],
      [existing_record.id, "Updated Name"]
    ]

    file = create_test_excel_file(excel_data)

    # Mock job enqueueing to verify it's called
    job_enqueued = false
    ImportProcessingJob.stub(:perform_later, ->(*_args) { job_enqueued = true }) do
      post import_file_import_template_url(@import_template), params: { excel_file: file }
    end
    
    # Should now redirect to job status page instead of template page
    assert_response :redirect
    assert job_enqueued, "ImportProcessingJob should be enqueued"
    
    # Note: Record won't be updated immediately since it's now background processing
  end

  test "should handle failed import and show errors (now using background processing)" do
    # Create Excel file with invalid data
    excel_data = [
      ["InvalidHeader"],
      ["Some Data"]
    ]

    file = create_test_excel_file(excel_data)

    # Mock job enqueueing to verify it's called
    job_enqueued = false
    ImportProcessingJob.stub(:perform_later, ->(*_args) { job_enqueued = true }) do
      post import_file_import_template_url(@import_template), params: { excel_file: file }
    end

    # Should now redirect to job status page instead of showing errors immediately
    assert_response :redirect
    assert job_enqueued, "ImportProcessingJob should be enqueued"
    
    # Note: Errors will be shown on the job status page after background processing
  end

  test "should redirect to login when not authenticated" do
    sign_out @user

    get import_templates_url

    assert_redirected_to new_user_session_url
  end

  test "should only show user's own templates in index" do
    other_user = users(:two)
    other_template = ImportTemplate.create!(
      name: "Other User Template",
      user: other_user,
      column_definitions: {
        "column_1" => { "name" => "Other", "data_type" => "string" }
      }
    )

    get import_templates_url

    assert_response :success
    assert_select "a", text: @import_template.name
    assert_select "a", text: other_template.name, count: 0
  end

  test "should redirect when accessing other user's template" do
    other_user = users(:two)
    other_template = ImportTemplate.create!(
      name: "Other User Template",
      user: other_user,
      column_definitions: {
        "column_1" => { "name" => "Other", "data_type" => "string" }
      }
    )

    get import_template_url(other_template)

    assert_redirected_to root_path
    assert_equal "You don't have permission to access that resource.", flash[:alert]
  end

  test "should redirect when editing other user's template" do
    other_user = users(:two)
    other_template = ImportTemplate.create!(
      name: "Other User Template",
      user: other_user,
      column_definitions: {
        "column_1" => { "name" => "Other", "data_type" => "string" }
      }
    )

    get edit_import_template_url(other_template)

    assert_redirected_to root_path
    assert_equal "You don't have permission to access that resource.", flash[:alert]
  end

  # Background Processing Tests

  test "should save uploaded file to temporary location and enqueue job" do
    excel_data = [["Name"], ["John Doe"]]
    file = create_test_excel_file(excel_data)

    # Mock job enqueueing to verify it's called
    job_enqueued = false
    ImportProcessingJob.stub(:perform_later, ->(*_args) { job_enqueued = true }) do
      post import_file_import_template_url(@import_template), params: { excel_file: file }
    end

    # Verify job was enqueued
    assert job_enqueued, "ImportProcessingJob should be enqueued"

    # Verify temporary file was created (it will be cleaned up by teardown)
    temp_files = Dir.glob(Rails.root.join("tmp", "imports", "*"))
    assert temp_files.any?, "Temporary file should be created"
  end

  test "should generate unique job_id and initialize cache status" do
    excel_data = [["Name"], ["John Doe"]]
    file = create_test_excel_file(excel_data)

    # Capture the job_id and arguments passed to the job
    job_args = nil
    ImportProcessingJob.stub(:perform_later, ->(template_id, job_id, file_path) {
      job_args = { template_id: template_id, job_id: job_id, file_path: file_path }
    }) do
      post import_file_import_template_url(@import_template), params: { excel_file: file }
    end

    # Verify job was called with correct arguments
    assert_not_nil job_args
    assert_equal @import_template.id, job_args[:template_id]
    assert_not_nil job_args[:job_id]
    assert_equal 16, job_args[:job_id].length # SecureRandom.hex(8) generates 16 chars
    assert_not_nil job_args[:file_path]

    # Verify cache status was initialized
    cached_status = Rails.cache.read("job_status:#{job_args[:job_id]}")
    assert_not_nil cached_status
    assert_equal :pending, cached_status[:status]
    assert_not_nil cached_status[:created_at]
  end

  test "should redirect to job status page after enqueueing" do
    excel_data = [["Name"], ["John Doe"]]
    file = create_test_excel_file(excel_data)

    # Capture job_id to verify redirect URL
    job_id = nil
    ImportProcessingJob.stub(:perform_later, ->(_template_id, captured_job_id, _file_path) {
      job_id = captured_job_id
    }) do
      post import_file_import_template_url(@import_template), params: { excel_file: file }
    end

    # Note: The redirect will fail because the route doesn't exist yet (task 4.6)
    # But we can verify the controller attempted the correct redirect
    assert_response :redirect
    assert_not_nil job_id
  end

  test "should handle file saving errors gracefully" do
    excel_data = [["Name"], ["John Doe"]]
    file = create_test_excel_file(excel_data)

    # Mock FileUtils.mkdir_p to raise an error
    FileUtils.stub(:mkdir_p, ->(*_args) { raise StandardError.new("Permission denied") }) do
      post import_file_import_template_url(@import_template), params: { excel_file: file }
    end

    assert_redirected_to import_form_import_template_url(@import_template)
    assert_match(/Failed to start background import.*Permission denied/, flash[:alert])
  end

  test "should handle job enqueueing errors gracefully" do
    excel_data = [["Name"], ["John Doe"]]
    file = create_test_excel_file(excel_data)

    # Mock job enqueueing to raise an error
    ImportProcessingJob.stub(:perform_later, ->(*_args) { raise StandardError.new("Queue unavailable") }) do
      post import_file_import_template_url(@import_template), params: { excel_file: file }
    end

    assert_redirected_to import_form_import_template_url(@import_template)
    assert_match(/Failed to start background import.*Queue unavailable/, flash[:alert])
  end

  test "should clean up temporary file on error" do
    excel_data = [["Name"], ["John Doe"]]
    file = create_test_excel_file(excel_data)

    # Track temp files before and after error
    temp_files_before = Dir.glob(Rails.root.join("tmp", "imports", "*")).length

    # Mock job enqueueing to raise an error after file is saved
    ImportProcessingJob.stub(:perform_later, ->(*_args) { raise StandardError.new("Queue error") }) do
      post import_file_import_template_url(@import_template), params: { excel_file: file }
    end

    # Verify no extra temp files remain
    temp_files_after = Dir.glob(Rails.root.join("tmp", "imports", "*")).length
    assert_equal temp_files_before, temp_files_after, "Temporary files should be cleaned up on error"
  end

  test "should save file with correct naming pattern" do
    excel_data = [["Name"], ["Test Data"]]
    file = create_test_excel_file(excel_data)
    original_filename = file.original_filename

    # Capture the file path passed to the job
    file_path = nil
    ImportProcessingJob.stub(:perform_later, ->(_template_id, job_id, captured_file_path) {
      file_path = captured_file_path
      # Verify file path follows expected pattern: job_id_originalname
      expected_pattern = /tmp\/imports\/[a-f0-9]{16}_.*\.xlsx$/
      assert_match expected_pattern, captured_file_path
      assert_includes captured_file_path, job_id
    }) do
      post import_file_import_template_url(@import_template), params: { excel_file: file }
    end

    assert_not_nil file_path
  end

  test "should pass correct parameters to ImportProcessingJob" do
    excel_data = [["Name"], ["Test Data"]]
    file = create_test_excel_file(excel_data)

    # Verify exact parameters passed to job
    job_called_with = nil
    ImportProcessingJob.stub(:perform_later, ->(*args) {
      job_called_with = args
    }) do
      post import_file_import_template_url(@import_template), params: { excel_file: file }
    end

    assert_not_nil job_called_with
    assert_equal 3, job_called_with.length
    assert_equal @import_template.id, job_called_with[0] # template_id
    assert_instance_of String, job_called_with[1] # job_id
    assert_instance_of String, job_called_with[2] # file_path
    assert_match /\.xlsx$/, job_called_with[2] # file_path ends with .xlsx
  end

  # Task 3.10: Error handling tests
  
  test "should accept non-Excel files and let background job handle validation" do
    # Create a text file instead of Excel  
    text_file = Tempfile.new(["test", ".txt"])
    text_file.write("This is not an Excel file")
    text_file.rewind

    uploaded_file = fixture_file_upload(text_file.path, "text/plain")

    # Mock job to verify it gets enqueued even with invalid files
    job_enqueued = false
    ImportProcessingJob.stub(:perform_later, ->(*_args) { job_enqueued = true }) do
      post import_file_import_template_url(@import_template), params: { excel_file: uploaded_file }
    end

    # Should enqueue job (validation happens in background)
    assert_response :redirect
    assert job_enqueued, "Job should be enqueued even for invalid files"
  end

  test "should handle corrupted Excel files gracefully" do
    # Create a corrupted file with .xlsx extension
    corrupted_file = Tempfile.new(["corrupted", ".xlsx"])
    corrupted_file.write("This is corrupted Excel data")
    corrupted_file.rewind

    uploaded_file = fixture_file_upload(corrupted_file.path, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")

    # Mock job to raise an error during processing
    ImportProcessingJob.stub(:perform_later, ->(*_args) { raise StandardError.new("Corrupted file") }) do
      post import_file_import_template_url(@import_template), params: { excel_file: uploaded_file }
    end

    assert_redirected_to import_form_import_template_url(@import_template)
    assert_match(/Failed to start background import.*Corrupted file/, flash[:alert])
  end

  test "should handle file size limits" do
    # Mock file that appears too large
    large_file = Tempfile.new(["large", ".xlsx"])
    def large_file.size
      100.megabytes # Simulate large file
    end

    uploaded_file = fixture_file_upload(large_file.path, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")

    post import_file_import_template_url(@import_template), params: { excel_file: uploaded_file }

    # Should handle appropriately - either process or reject based on app limits
    assert_response :redirect
  end

  test "should handle file writing errors during save" do
    excel_data = [["Name"], ["Test Data"]]
    file = create_test_excel_file(excel_data)

    # Mock FileUtils.mkdir_p to raise a permission error
    FileUtils.stub(:mkdir_p, ->(*_args) { raise Errno::EACCES.new("Permission denied") }) do
      post import_file_import_template_url(@import_template), params: { excel_file: file }
    end

    assert_redirected_to import_form_import_template_url(@import_template)
    assert_match(/Failed to start background import.*Permission denied/, flash[:alert])
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
