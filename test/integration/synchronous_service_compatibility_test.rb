# frozen_string_literal: true

require "test_helper"

class SynchronousServiceCompatibilityTest < ActiveSupport::TestCase
  include ExcelFixtureHelper
  def setup
    @user = users(:one)
    @template = ImportTemplate.create!(
      name: "Sync Test Template",
      description: "Template for testing synchronous service compatibility",
      user: @user
    )

    @name_column = @template.template_columns.create!(
      name: "Name",
      data_type: "string", 
      column_number: 1,
      required: false
    )

    @age_column = @template.template_columns.create!(
      name: "Age",
      data_type: "number",
      column_number: 2,
      required: false
    )

    @active_column = @template.template_columns.create!(
      name: "Active",
      data_type: "boolean",
      column_number: 3,
      required: false
    )
  end

  test "ExcelImportService works identically in synchronous and background contexts" do
    # Create test data
    excel_data = [
      ["Name", "Age", "Active"],
      ["Sync User 1", "30", "true"],
      ["Sync User 2", "25", "false"]
    ]

    # Test 1: Direct synchronous service call (as used in controller)
    sync_file = create_test_excel_file(excel_data)
    sync_service = ExcelImportService.new(sync_file, @template)
    sync_result = sync_service.process_import

    # Verify synchronous result
    assert sync_result.success, "Synchronous service should succeed: #{sync_result.errors.join('; ')}"
    assert_equal 2, sync_result.created_records.length
    sync_created_count = sync_result.created_records.length
    sync_summary = sync_result.summary

    # Test 2: Background job simulation using same service unchanged
    @template.data_records.destroy_all # Clean slate

    # Create identical file as background job would
    job_id = SecureRandom.hex(8)
    background_file_path = save_excel_to_temp_location(excel_data, job_id)
    background_uploaded_file = ActionDispatch::Http::UploadedFile.new(
      tempfile: File.open(background_file_path),
      filename: File.basename(background_file_path),
      type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    )

    # Call the same service with same parameters
    background_service = ExcelImportService.new(background_uploaded_file, @template)
    background_result = background_service.process_import

    # Verify identical results
    assert background_result.success, "Background service should succeed: #{background_result.errors.join('; ')}"
    assert_equal sync_created_count, background_result.created_records.length
    assert_includes background_result.summary, "created"

    # Verify data integrity is identical
    background_records = @template.data_records.reload
    assert_equal 2, background_records.count

    sync_user_1 = background_records.find { |r| r.value_for_column(@name_column) == "Sync User 1" }
    sync_user_2 = background_records.find { |r| r.value_for_column(@name_column) == "Sync User 2" }

    assert_not_nil sync_user_1
    assert_not_nil sync_user_2
    assert_equal "30", sync_user_1.value_for_column(@age_column)
    assert_equal "true", sync_user_1.value_for_column(@active_column)
    assert_equal "25", sync_user_2.value_for_column(@age_column)
    assert_equal "false", sync_user_2.value_for_column(@active_column)

    # Cleanup
    background_uploaded_file.tempfile.close
    File.delete(background_file_path) if File.exist?(background_file_path)
  end

  test "ExcelExportService remains fully synchronous without any background job dependencies" do
    # Create test data for export
    record1 = @template.data_records.create!
    record1.set_value_for_column(@name_column, "Export Sync Test 1")
    record1.set_value_for_column(@age_column, "35")
    record1.set_value_for_column(@active_column, "true")

    record2 = @template.data_records.create!
    record2.set_value_for_column(@name_column, "Export Sync Test 2")
    record2.set_value_for_column(@age_column, "28")
    record2.set_value_for_column(@active_column, "false")

    # Test synchronous export calls as used in controller
    service = ExcelExportService.new(@template)

    # Test template export (used in controller)
    template_package = service.generate_template_file
    assert_not_nil template_package
    assert template_package.respond_to?(:to_stream)
    template_stream = template_package.to_stream
    assert template_stream.size > 0

    # Test data export (used in controller)
    data_package = service.generate_data_file
    assert_not_nil data_package
    assert data_package.respond_to?(:to_stream)
    data_stream = data_package.to_stream
    assert data_stream.size > 0

    # Test sample export (used in controller)
    sample_package = service.generate_sample_file
    assert_not_nil sample_package
    assert sample_package.respond_to?(:to_stream)
    sample_stream = sample_package.to_stream
    assert sample_stream.size > 0

    # Verify all exports are immediately available (synchronous)
    assert data_stream.size > template_stream.size, "Data export should be larger than template"
    assert template_stream.size > 0, "Template export should contain data"
    assert sample_stream.size > 0, "Sample export should contain data"

    # Verify content can be read immediately (no background processing delays)
    template_content = read_package_content(template_package)
    data_content = read_package_content(data_package)
    sample_content = read_package_content(sample_package)

    # Template should have headers only (including hidden __record_id column)
    assert_equal 1, template_content.count, "Template should have header row only"
    expected_headers = ["__record_id", "Name", "Age", "Active"]
    assert_equal expected_headers, template_content.first

    # Data export should have headers + data
    assert_equal 3, data_content.count, "Data export should have header + 2 data rows"
    assert_equal expected_headers, data_content.first
    assert_includes data_content[1], "Export Sync Test 1"
    assert_includes data_content[2], "Export Sync Test 2"

    # Sample should have headers + sample data (sample may include multiple rows)
    assert sample_content.count >= 2, "Sample should have at least header + 1 sample row"
    assert_equal expected_headers, sample_content.first
  end

  test "services handle errors identically in synchronous and background contexts" do
    # Create invalid data that will cause validation errors
    invalid_excel_data = [
      ["Name", "Age", "Active"],
      ["", "invalid_age", "invalid_boolean"] # All invalid
    ]

    # Test synchronous error handling
    sync_file = create_test_excel_file(invalid_excel_data)
    sync_service = ExcelImportService.new(sync_file, @template)
    sync_result = sync_service.process_import

    assert_not sync_result.success, "Synchronous service should fail with invalid data"
    sync_error_count = sync_result.errors.length
    sync_errors = sync_result.errors

    # Test background context error handling (using same service)
    job_id = SecureRandom.hex(8)
    background_file_path = save_excel_to_temp_location(invalid_excel_data, job_id)
    background_uploaded_file = ActionDispatch::Http::UploadedFile.new(
      tempfile: File.open(background_file_path),
      filename: File.basename(background_file_path),
      type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    )

    background_service = ExcelImportService.new(background_uploaded_file, @template)
    background_result = background_service.process_import

    # Verify error handling is identical
    assert_not background_result.success, "Background service should fail with same invalid data"
    assert_equal sync_error_count, background_result.errors.length

    # Verify error types are consistent
    combined_sync_errors = sync_errors.join("; ")
    combined_bg_errors = background_result.errors.join("; ")
    
    assert_includes combined_sync_errors, "Could not convert"
    assert_includes combined_bg_errors, "Could not convert"

    # Cleanup
    background_uploaded_file.tempfile.close
    File.delete(background_file_path) if File.exist?(background_file_path)
  end

  test "services maintain thread safety when used synchronously in multi-threaded environments" do
    # Test that synchronous service calls are thread-safe
    excel_data = [
      ["Name", "Age", "Active"],
      ["Thread Test", "40", "true"]
    ]

    results = []
    threads = []
    
    # Run multiple synchronous service calls concurrently
    5.times do |i|
      threads << Thread.new do
        # Create separate template for each thread to avoid conflicts
        thread_template = ImportTemplate.create!(
          name: "Thread Test #{i}",
          description: "Template for thread #{i}",
          user: @user
        )
        
        thread_template.template_columns.create!(
          name: "Name", data_type: "string", column_number: 1, required: false
        )
        thread_template.template_columns.create!(
          name: "Age", data_type: "number", column_number: 2, required: false
        )
        thread_template.template_columns.create!(
          name: "Active", data_type: "boolean", column_number: 3, required: false
        )

        sync_file = create_test_excel_file(excel_data)
        service = ExcelImportService.new(sync_file, thread_template)
        result = service.process_import
        
        results << { thread: i, success: result.success, count: result.created_records.length }
      end
    end

    # Wait for all threads to complete
    threads.each(&:join)

    # Verify all succeeded
    assert_equal 5, results.length
    results.each do |result|
      assert result[:success], "Thread #{result[:thread]} should succeed"
      assert_equal 1, result[:count], "Thread #{result[:thread]} should create 1 record"
    end
  end

  test "services work without any background job infrastructure" do
    # Test that services can be used in environments without background jobs
    # Simulate this by ensuring no job-related code is called

    excel_data = [
      ["Name", "Age", "Active"],
      ["No BG Job", "50", "false"]
    ]

    # Disable background job processing to ensure synchronous operation
    original_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :inline

    begin
      # Create and process import synchronously
      sync_file = create_test_excel_file(excel_data)
      service = ExcelImportService.new(sync_file, @template)
      result = service.process_import

      # Verify it works without background job infrastructure
      assert result.success, "Service should work without background jobs: #{result.errors.join('; ')}"
      assert_equal 1, result.created_records.length
      assert_includes result.summary, "created"

      # Test export service also works without background jobs
      export_service = ExcelExportService.new(@template)
      package = export_service.generate_data_file
      assert_not_nil package
      assert package.to_stream.size > 0

    ensure
      # Restore original queue adapter
      ActiveJob::Base.queue_adapter = original_adapter
    end
  end

  test "controller methods use services synchronously without background job coupling" do
    # Verify that the synchronous controller methods work as expected
    # This simulates what happens when controller calls services directly

    # Test import service call (as done in process_excel_import method)
    excel_data = [
      ["Name", "Age", "Active"],
      ["Controller Test", "60", "true"]
    ]
    
    uploaded_file = create_test_excel_file(excel_data)
    
    # Simulate controller service call
    service = ExcelImportService.new(uploaded_file, @template)
    import_result = service.process_import
    
    # Verify controller would get proper result
    assert import_result.success, "Controller import should succeed"
    assert_respond_to import_result, :summary
    assert import_result.summary.present?
    assert_equal 1, import_result.created_records.length

    # Test export service calls (as done in export_* methods)
    export_service = ExcelExportService.new(@template)
    
    # Simulate export_template call
    template_package = export_service.generate_template_file
    assert_not_nil template_package
    template_stream = template_package.to_stream
    assert template_stream.respond_to?(:read)
    assert template_stream.size > 0

    # Simulate export_data call  
    data_package = export_service.generate_data_file
    assert_not_nil data_package
    data_stream = data_package.to_stream
    assert data_stream.respond_to?(:read)
    assert data_stream.size > 0

    # Simulate export_sample call
    sample_package = export_service.generate_sample_file
    assert_not_nil sample_package
    sample_stream = sample_package.to_stream
    assert sample_stream.respond_to?(:read)
    assert sample_stream.size > 0

    # All should be immediately available for send_data
    template_content = template_stream.read
    data_content = data_stream.read
    sample_content = sample_stream.read

    assert template_content.length > 0
    assert data_content.length > 0
    assert sample_content.length > 0
    assert data_content.length > template_content.length, "Data should be larger than template"
  end

  private

  def create_test_excel_file(data)
    # Create a file with the exact data needed for the test
    create_simple_excel_file(data, "sync_compat_test")
  end

  def save_excel_to_temp_location(excel_data, job_id)
    require "caxlsx"

    package = Axlsx::Package.new
    workbook = package.workbook
    worksheet = workbook.add_worksheet(name: "Test Data")
    excel_data.each { |row| worksheet.add_row(row) }

    temp_file_path = Rails.root.join("tmp", "sync_test_#{job_id}.xlsx")
    FileUtils.mkdir_p(File.dirname(temp_file_path))
    package.serialize(temp_file_path)
    
    temp_file_path.to_s
  end

  def read_package_content(package)
    require "roo"
    
    temp_file = Tempfile.new(["read_test", ".xlsx"])
    temp_file.binmode
    temp_file.write(package.to_stream.string)
    temp_file.close

    workbook = Roo::Excelx.new(temp_file.path)
    rows = []
    (workbook.first_row..workbook.last_row).each do |row_num|
      rows << workbook.row(row_num)
    end
    
    temp_file.unlink
    rows
  end
end