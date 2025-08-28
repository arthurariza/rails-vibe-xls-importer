# frozen_string_literal: true

class ExcelImportService < ApplicationService
  attr_reader :file, :import_template, :import_result

  def initialize(file, import_template)
    @file = file
    @import_template = import_template
    @import_result = ImportResult.new
  end

  def process_import
    # Validate file format
    return import_result unless validate_file_format

    # Open and read the Excel file
    workbook = open_workbook
    return import_result unless workbook

    # Extract headers and validate
    headers = extract_headers(workbook)
    validation_service = HeaderValidationService.new(headers, import_template)
    header_validation = validation_service.validate_headers

    unless header_validation.valid
      import_result.success = false
      import_result.errors = header_validation.errors
      return import_result
    end

    # Process data rows
    process_data_rows(workbook, header_validation.header_mapping)

    import_result
  end

  private

  def validate_file_format
    if file.blank?
      import_result.add_error("No file provided")
      return false
    end

    allowed_types = [
      "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", # .xlsx
      "application/vnd.ms-excel", # .xls
      "application/excel",
      "application/x-excel"
    ]

    unless allowed_types.include?(file.content_type)
      import_result.add_error("Invalid file format. Please upload an Excel file (.xlsx or .xls)")
      return false
    end

    if file.size > 10.megabytes
      import_result.add_error("File too large. Maximum size is 10MB")
      return false
    end

    true
  end

  def open_workbook
    require "roo"

    begin
      # Determine file type and open appropriately
      if file.original_filename.match?(/\.xlsx$/i)
        Roo::Excelx.new(file.tempfile.path)
      elsif file.original_filename.match?(/\.xls$/i)
        Roo::Excel.new(file.tempfile.path)
      else
        # Try to auto-detect
        Roo::Spreadsheet.open(file.tempfile.path)
      end
    rescue StandardError => e
      import_result.add_error("Could not read Excel file: #{e.message}")
      nil
    end
  end

  def extract_headers(workbook)
    # Get the first row as headers
    first_row = workbook.row(workbook.first_row)
    first_row.compact.map(&:to_s)
  end

  def process_data_rows(workbook, header_mapping)
    batch_id = SecureRandom.hex(8)
    row_number = 1 # Start counting from data rows (excluding header)

    ((workbook.first_row + 1)..workbook.last_row).each do |row_index|
      row_number += 1
      row_data = workbook.row(row_index)

      # Skip completely empty rows
      next if row_data.compact.empty?

      begin
        process_single_row(row_data, header_mapping, batch_id, row_number)
        import_result.processed_count += 1
      rescue StandardError => e
        import_result.add_row_error(row_number, "Error processing row: #{e.message}")
        import_result.error_count += 1
      end
    end

    import_result.success = import_result.error_count.zero?
    import_result.import_batch_id = batch_id
  end

  def process_single_row(row_data, header_mapping, batch_id, row_number)
    # Build attributes hash
    attributes = {
      import_template: import_template,
      import_batch_id: batch_id
    }

    # Map Excel columns to our database columns
    header_mapping.each do |excel_col_index, db_col_number|
      value = row_data[excel_col_index]
      next if value.blank?

      # Get column definition for data type conversion
      column_def = import_template.column_definition(db_col_number)
      converted_value = convert_value(value, column_def["data_type"], row_number)

      attributes[:"column_#{db_col_number}"] = converted_value
    end

    # Create the data record
    record = DataRecord.new(attributes)

    unless record.save
      error_messages = record.errors.full_messages.join("; ")
      raise "Validation failed: #{error_messages}"
    end

    import_result.created_records << record
  end

  def convert_value(value, data_type, row_number)
    return nil if value.blank?

    case data_type
    when "string"
      value.to_s.strip
    when "number"
      convert_to_number(value, row_number)
    when "date"
      convert_to_date(value, row_number)
    when "boolean"
      convert_to_boolean(value, row_number)
    else
      value.to_s.strip
    end
  end

  def convert_to_number(value, row_number)
    case value
    when Numeric
      value
    when String
      # Remove common number formatting
      cleaned = value.gsub(/[,\s]/, "")
      Float(cleaned)
    else
      raise "Invalid number format: #{value}"
    end
  rescue ArgumentError
    raise "Could not convert '#{value}' to number on row #{row_number}"
  end

  def convert_to_date(value, row_number)
    case value
    when Date
      value.to_s
    when DateTime, Time
      value.to_date.to_s
    when String
      Date.parse(value).to_s
    when Numeric
      # Assume Excel date serial number
      Date.new(1900, 1, 1) + value.to_i - 2
    else
      raise "Invalid date format: #{value}"
    end
  rescue ArgumentError
    raise "Could not convert '#{value}' to date on row #{row_number}"
  end

  def convert_to_boolean(value, row_number)
    case value.to_s.downcase.strip
    when "true", "yes", "y", "1"
      "true"
    when "false", "no", "n", "0"
      "false"
    when ""
      nil
    else
      raise "Could not convert '#{value}' to boolean on row #{row_number}. Use true/false, yes/no, or 1/0"
    end
  end

  class ImportResult
    attr_accessor :success, :errors, :processed_count, :error_count, :created_records, :import_batch_id

    def initialize
      @success = false
      @errors = []
      @processed_count = 0
      @error_count = 0
      @created_records = []
      @import_batch_id = nil
    end

    def add_error(message)
      @errors << message
    end

    def add_row_error(row_number, message)
      @errors << "Row #{row_number}: #{message}"
    end

    def success_count
      created_records.count
    end

    def has_errors?
      errors.any?
    end

    def summary
      if success
        "Successfully imported #{success_count} records"
      else
        "Import completed with #{error_count} errors. #{success_count} records imported."
      end
    end
  end
end
