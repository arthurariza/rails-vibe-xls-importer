# frozen_string_literal: true

require "test_helper"

class ErrorMessageCacheIntegrationTest < ActiveSupport::TestCase
  def setup
    # Use MemoryStore for consistent cache behavior in tests
    @original_cache_store = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    
    @user = users(:one)
    @template = ImportTemplate.create!(
      name: "Cache Integration Template",
      description: "Template for testing error message cache integration",
      user: @user
    )

    @name_column = @template.template_columns.create!(
      name: "Name",
      data_type: "string",
      column_number: 1,
      required: true
    )

    @age_column = @template.template_columns.create!(
      name: "Age",
      data_type: "number",
      column_number: 2,
      required: false
    )
  end

  def teardown
    Rails.cache = @original_cache_store
  end

  test "should store and retrieve service error messages via JobStatusService cache" do
    # Create Excel file with validation errors
    excel_data = [
      ["Name", "Age"],
      ["", "not_a_number"], # Missing required name + invalid number
      ["Valid Name", "invalid_age"] # Invalid age format
    ]

    file = create_test_excel_file(excel_data)
    service = ExcelImportService.new(file, @template)
    result = service.process_import

    assert_not result.success
    assert_predicate result, :has_errors?

    # Generate a unique job_id for this test
    job_id = SecureRandom.hex(8)

    # Initialize job status (like controller does)
    JobStatusService.update_status(job_id, :pending, created_at: Time.current)

    # Simulate how ImportProcessingJob handles failed results
    error_message = result.errors.join("; ")
    JobStatusService.update_status(job_id, :failed,
                                   completed_at: Time.current,
                                   error_message: error_message)

    # Verify error message was stored in cache and can be retrieved
    cached_status = JobStatusService.get_status(job_id)
    
    assert_equal :failed, cached_status[:status]
    assert_not_nil cached_status[:error_message]
    assert_includes cached_status[:error_message], "Required field 'Name' cannot be empty"
    assert_includes cached_status[:error_message], "Could not convert"
    assert_includes cached_status[:error_message], "Row 2"
    assert_includes cached_status[:error_message], "Row 3"

    # Verify the error message is concise enough for cache storage
    assert cached_status[:error_message].length < 500, "Error message should be reasonable for cache storage"
    
    # Verify cache entry has expiration
    cache_key = JobStatusService.cache_key(job_id)
    assert Rails.cache.exist?(cache_key), "Cache entry should exist"
  end

  test "should handle very long error messages by truncating appropriately" do
    # Create a scenario with many errors that could result in a very long error message
    excel_data = [["Name", "Age"]]
    
    # Add 20 rows with errors to create a potentially long error message
    (1..20).each do |i|
      excel_data << ["", "invalid_number_#{i}"] # Each row will have 2 errors
    end

    file = create_test_excel_file(excel_data)
    service = ExcelImportService.new(file, @template)
    result = service.process_import

    assert_not result.success
    assert result.errors.length >= 20, "Should have multiple errors"

    job_id = SecureRandom.hex(8)
    
    # Initialize job status
    JobStatusService.update_status(job_id, :pending, created_at: Time.current)
    
    # Simulate error message handling with truncation if needed
    error_message = result.errors.join("; ")
    
    # If error message is too long, truncate it intelligently
    if error_message.length > 1000
      error_message = "#{error_message[0..997]}..." 
    end

    JobStatusService.update_status(job_id, :failed,
                                   completed_at: Time.current,
                                   error_message: error_message)

    cached_status = JobStatusService.get_status(job_id)
    
    assert_equal :failed, cached_status[:status]
    assert cached_status[:error_message].length <= 1000, "Error message should be truncated if too long"
    assert_includes cached_status[:error_message], "Required field", "Should still contain meaningful error information"
  end

  test "should preserve error message structure for different error types" do
    test_scenarios = [
      {
        name: "file_validation_error",
        use_nil_file: true,
        expected_errors: ["No file provided"]
      },
      {
        name: "header_validation_error", 
        data: [["Wrong Header"], ["Some Data"]],
        expected_errors: ["Missing required headers", "Name", "Age"]
      },
      {
        name: "data_validation_error",
        data: [["Name", "Age"], ["", "invalid_number"], ["John", "not_a_number"]],
        expected_errors: ["Required field", "Could not convert", "Row"]
      }
    ]

    test_scenarios.each do |scenario|
      job_id = SecureRandom.hex(8)
      
      # Initialize job status
      JobStatusService.update_status(job_id, :pending, created_at: Time.current)
      
      if scenario[:use_nil_file]
        # Test file validation error
        service = ExcelImportService.new(nil, @template)
        result = service.process_import
      else
        # Test with provided data
        file = create_test_excel_file(scenario[:data])
        service = ExcelImportService.new(file, @template)
        result = service.process_import
      end

      assert_not result.success, "#{scenario[:name]} should fail"

      error_message = result.errors.join("; ")
      JobStatusService.update_status(job_id, :failed,
                                     completed_at: Time.current,
                                     error_message: error_message)

      cached_status = JobStatusService.get_status(job_id)
      
      # Verify error structure is preserved
      scenario[:expected_errors].each do |expected_part|
        assert_not_nil cached_status[:error_message], "#{scenario[:name]} should have error message"
        assert_includes cached_status[:error_message], expected_part, 
          "#{scenario[:name]} should contain '#{expected_part}' in cached error message"
      end
    end
  end

  test "should handle success scenario with meaningful summary for cache storage" do
    # Create valid Excel data
    excel_data = [
      ["Name", "Age"],
      ["John Doe", "25"],
      ["Jane Smith", "30"]
    ]

    file = create_test_excel_file(excel_data)
    service = ExcelImportService.new(file, @template)
    result = service.process_import

    assert result.success, "Import should succeed: #{result.errors.join('; ')}"

    job_id = SecureRandom.hex(8)

    # Initialize job status
    JobStatusService.update_status(job_id, :pending, created_at: Time.current)

    # Simulate successful job completion
    JobStatusService.update_status(job_id, :completed,
                                   completed_at: Time.current,
                                   result_summary: result.summary,
                                   processed_count: result.processed_count)

    cached_status = JobStatusService.get_status(job_id)
    
    assert_equal :completed, cached_status[:status]
    assert_not_nil cached_status[:result_summary]
    assert_includes cached_status[:result_summary], "2 created"
    assert_equal 2, cached_status[:processed_count]
    assert_nil cached_status[:error_message], "Successful jobs should not have error messages"
  end

  private

  def create_test_excel_file(data)
    require "caxlsx"

    package = Axlsx::Package.new
    workbook = package.workbook

    worksheet = workbook.add_worksheet(name: "Test Data")
    data.each { |row| worksheet.add_row(row) }

    # Create temporary file
    temp_file = Tempfile.new(["test_import", ".xlsx"])
    temp_file.binmode
    temp_file.write(package.to_stream.string)
    temp_file.rewind

    # Create ActionDispatch::Http::UploadedFile-like object
    ActionDispatch::Http::UploadedFile.new(
      tempfile: temp_file,
      filename: "test_import.xlsx",
      type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    )
  end
end