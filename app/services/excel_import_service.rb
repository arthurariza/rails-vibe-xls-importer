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
    validation_service = HeaderValidationService.new(headers, import_template, @has_id_column)
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
    all_headers = first_row.compact.map(&:to_s)

    # Check if first column is our hidden ID column
    if all_headers.first == "__record_id"
      # Store ID column presence for later use
      @has_id_column = true
      # Return headers without the ID column for validation
      all_headers[1..]
    else
      @has_id_column = false
      all_headers
    end
  end

  def process_data_rows(workbook, header_mapping)
    # Build sync plan by parsing all rows first
    sync_plan = build_sync_plan(workbook, header_mapping)

    # Validate all data before making any database changes
    return import_result unless validate_all_data(sync_plan)

    # Execute synchronization within transaction
    execute_sync_transaction(sync_plan)
  end

  def build_sync_plan(workbook, header_mapping)
    sync_plan = {
      to_update: [],
      to_create: [],
      to_delete: [],
      existing_ids: []
    }

    row_number = 1 # Start counting from data rows (excluding header)

    ((workbook.first_row + 1)..workbook.last_row).each do |row_index|
      row_number += 1
      row_data = workbook.row(row_index)

      # Skip completely empty rows
      next if row_data.compact.empty?

      # Extract ID from first column (if ID column exists)
      record_id = @has_id_column ? row_data[0]&.to_i : nil

      # Build record attributes (without validation here)
      begin
        attributes = build_record_attributes_raw(row_data, header_mapping, row_number)
      rescue StandardError => e
        # Store error for validation phase
        attributes = { _error: e.message, _row_number: row_number }
      end

      if record_id&.positive?
        # Existing record to update
        sync_plan[:to_update] << { id: record_id, attributes: attributes, row_number: row_number }
        sync_plan[:existing_ids] << record_id
      else
        # New record to create
        sync_plan[:to_create] << { attributes: attributes, row_number: row_number }
      end
    end

    # Find records to delete (existing records not in import file)
    if @has_id_column
      all_template_record_ids = import_template.data_records.pluck(:id)
      sync_plan[:to_delete] = all_template_record_ids - sync_plan[:existing_ids]
    end

    sync_plan
  end

  def build_record_attributes_raw(row_data, header_mapping, row_number)
    attributes = { import_template: import_template }
    data_record_values_attributes = []

    # Map Excel columns to our database columns using template columns
    header_mapping.each do |excel_col_index, template_column|
      # Adjust index if ID column is present (since headers were extracted without ID column)
      actual_col_index = @has_id_column ? excel_col_index + 1 : excel_col_index
      value = row_data[actual_col_index]

      # Check for required field validation
      raise "Required field '#{template_column.name}' cannot be empty" if template_column.required? && value.blank?

      next if value.blank?

      # Convert value according to column data type
      converted_value = convert_value(value, template_column.data_type, row_number)

      # Build attributes for data_record_values
      data_record_values_attributes << {
        template_column_id: template_column.id,
        value: converted_value
      }
    end

    attributes[:data_record_values_attributes] = data_record_values_attributes
    attributes
  end

  def validate_all_data(sync_plan)
    # Check for any parsing errors from sync plan building
    all_operations = sync_plan[:to_update] + sync_plan[:to_create]

    all_operations.each do |operation|
      # Check if there was a parsing error during sync plan building
      if operation[:attributes][:_error]
        import_result.add_row_error(operation[:row_number], operation[:attributes][:_error])
        next
      end

      # Skip validation for operations that had parsing errors
      next if operation[:attributes][:_error]

      begin
        if operation[:id]
          # Validate update operation
          existing_record = import_template.data_records.find_by(id: operation[:id])
          unless existing_record
            import_result.add_row_error(operation[:row_number], "Record with ID #{operation[:id]} not found")
            next
          end

          # Test if attributes are valid by simulating the column value updates
          # Create a duplicate record for validation without affecting the original
          test_record = existing_record.dup

          # Simulate updating each column value
          operation[:attributes][:data_record_values_attributes]&.each do |value_attrs|
            template_column = TemplateColumn.find(value_attrs[:template_column_id])
            # For validation, we just check if the value would be valid for the column type
            begin
              convert_value(value_attrs[:value], template_column.data_type, operation[:row_number])
            rescue StandardError => e
              import_result.add_row_error(operation[:row_number], e.message)
              break
            end
          end

          # Test if the record itself is still valid (without the data_record_values_attributes)
          basic_attributes = operation[:attributes].except(:data_record_values_attributes)
          test_record.assign_attributes(basic_attributes)
          unless test_record.valid?
            import_result.add_row_error(operation[:row_number],
                                        "Validation failed: #{test_record.errors.full_messages.join('; ')}")
          end
        else
          # Validate create operation
          new_record = DataRecord.new(operation[:attributes])
          unless new_record.valid?
            import_result.add_row_error(operation[:row_number],
                                        "Validation failed: #{new_record.errors.full_messages.join('; ')}")
          end
        end
      rescue StandardError => e
        import_result.add_row_error(operation[:row_number], "Error validating row: #{e.message}")
      end
    end

    # Return false if any validation errors occurred
    if import_result.has_errors?
      import_result.success = false
      return false
    end

    true
  end

  def execute_sync_transaction(sync_plan)
    batch_id = SecureRandom.hex(8)

    ActiveRecord::Base.transaction do
      # Delete records not present in import file
      if sync_plan[:to_delete].any?
        import_template.data_records.where(id: sync_plan[:to_delete]).destroy_all
        import_result.deleted_count = sync_plan[:to_delete].length
      end

      # Update existing records (skip any with errors)
      sync_plan[:to_update].each do |operation|
        next if operation[:attributes][:_error]

        record = import_template.data_records.find(operation[:id])

        # Update each column value individually using the set_value_for_column method
        operation[:attributes][:data_record_values_attributes]&.each do |value_attrs|
          template_column = TemplateColumn.find(value_attrs[:template_column_id])
          record.set_value_for_column(template_column, value_attrs[:value])
        end

        # Update the import_batch_id directly
        record.update!(import_batch_id: batch_id)
        import_result.updated_records << record
      end

      # Create new records (skip any with errors)
      sync_plan[:to_create].each do |operation|
        next if operation[:attributes][:_error]

        record = DataRecord.create!(operation[:attributes].merge(import_batch_id: batch_id))
        import_result.created_records << record
      end

      import_result.success = true
      import_result.import_batch_id = batch_id
      import_result.processed_count = sync_plan[:to_update].length + sync_plan[:to_create].length
    end
  rescue StandardError => e
    import_result.success = false
    import_result.add_error("Transaction failed: #{e.message}")
  end

  def process_single_row(row_data, header_mapping, batch_id, row_number)
    # Build attributes hash
    attributes = {
      import_template: import_template,
      import_batch_id: batch_id
    }
    data_record_values_attributes = []

    # Map Excel columns to our database columns using template columns
    header_mapping.each do |excel_col_index, template_column|
      # Adjust index if ID column is present (since headers were extracted without ID column)
      actual_col_index = @has_id_column ? excel_col_index + 1 : excel_col_index
      value = row_data[actual_col_index]
      next if value.blank?

      # Convert value according to column data type
      converted_value = convert_value(value, template_column.data_type, row_number)

      # Build attributes for data_record_values
      data_record_values_attributes << {
        template_column_id: template_column.id,
        value: converted_value
      }
    end

    attributes[:data_record_values_attributes] = data_record_values_attributes

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
    attr_accessor :success, :errors, :processed_count, :error_count, :created_records, :updated_records,
                  :deleted_count, :import_batch_id

    def initialize
      @success = false
      @errors = []
      @processed_count = 0
      @error_count = 0
      @created_records = []
      @updated_records = []
      @deleted_count = 0
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

    def updated_count
      updated_records.count
    end

    def total_changes
      created_records.count + updated_records.count + deleted_count
    end

    def has_errors?
      errors.any?
    end

    def summary
      if success
        parts = []
        parts << "#{created_records.count} created" if created_records.any?
        parts << "#{updated_records.count} updated" if updated_records.any?
        parts << "#{deleted_count} deleted" if deleted_count.positive?

        if parts.any?
          "Successfully synchronized: #{parts.join(', ')}"
        else
          "Import completed - no changes needed"
        end
      else
        "Import failed with #{error_count} errors. No changes made."
      end
    end
  end
end
