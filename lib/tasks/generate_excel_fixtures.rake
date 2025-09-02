# frozen_string_literal: true

namespace :test do
  desc "Generate Excel fixture files for tests"
  task generate_excel_fixtures: :environment do
    require "caxlsx"
    require "fileutils"

    fixtures_dir = Rails.root.join("test/fixtures/files")
    FileUtils.mkdir_p(fixtures_dir)

    # Basic templates for test scenarios
    excel_templates = {
      # Update existing records with IDs
      "update_existing_records.xlsx" => [
        ["__record_id", "Name", "Age", "Active"],
        [1, "John Updated", "31", "false"],
        [2, "Jane Updated", "26", "true"]
      ],

      # Mixed update and create
      "mixed_update_create.xlsx" => [
        ["__record_id", "Name", "Age", "Active"],
        [1, "John Updated", "31", "false"],
        ["", "Bob New", "35", "true"]
      ],

      # Only create new records (no ID column)
      "create_only_records.xlsx" => [
        ["Name", "Age", "Active"],
        ["Alice New", "28", "true"],
        ["Bob New", "32", "false"]
      ],

      # Validation error - invalid number
      "invalid_number_data.xlsx" => [
        ["__record_id", "Name", "Age", "Active"],
        [1, "John Updated", "invalid_number", "false"]
      ],

      # Non-existent record ID
      "non_existent_id.xlsx" => [
        ["__record_id", "Name", "Age", "Active"],
        [99_999, "Fake Record", "25", "true"]
      ],

      # Transaction rollback test
      "transaction_rollback.xlsx" => [
        ["__record_id", "Name", "Age", "Active"],
        [1, "John Updated", "31", "true"],
        ["", "New Record", "invalid_age", "true"]
      ],

      # Duplicate record IDs
      "duplicate_record_ids.xlsx" => [
        ["__record_id", "Name", "Age", "Active"],
        [1, "John First", "30", "true"],
        [1, "John Duplicate", "31", "false"]
      ],

      # Invalid record ID (non-numeric)
      "invalid_record_id.xlsx" => [
        ["__record_id", "Name", "Age", "Active"],
        ["not_a_number", "Invalid ID Record", "25", "true"]
      ],

      # No ID column (legacy format)
      "no_id_column.xlsx" => [
        ["Name", "Age", "Active"],
        ["Legacy Record", "40", "true"]
      ],

      # Mixed empty and nil IDs
      "mixed_empty_nil_ids.xlsx" => [
        ["__record_id", "Name", "Age", "Active"],
        [1, "John Updated", "31", "true"],
        ["", "New Record 1", "28", "false"],
        [nil, "New Record 2", "29", "true"]
      ],

      # Minimal columns template
      "minimal_columns.xlsx" => [
        ["Name", "Email"],
        ["Alice Johnson", "alice@example.com"],
        ["Bob Wilson", "bob@example.com"]
      ],

      # Large number of columns
      "many_columns.xlsx" => [
        ["Column 1", "Column 2", "Column 3", "Column 4", "Column 5", "Column 6"],
        ["A1", "A2", "A3", "A4", "A5", "A6"],
        ["B1", "B2", "B3", "B4", "B5", "B6"]
      ],

      # Missing required field
      "missing_required_field.xlsx" => [
        ["Required Field", "Optional Field"],
        ["", "Optional Value"]
      ],

      # Transaction integrity test
      "transaction_integrity.xlsx" => [
        ["Name", "Age"],
        ["Valid Person", "25"],
        ["", "30"],
        ["Another Valid", "35"]
      ],

      # Invalid date format
      "invalid_date_format.xlsx" => [
        ["Name", "Age", "Birth Date", "Active"],
        ["John Doe", "25", "invalid-date-format", "true"]
      ],

      # Invalid boolean format
      "invalid_boolean_format.xlsx" => [
        ["Name", "Age", "Active"],
        ["John Doe", "25", "not-a-boolean"]
      ],

      # Large dataset for performance testing
      "large_dataset.xlsx" => ([["Name", "Age", "Email", "Active"]] + 
        (1..100).map { |i| ["Person #{i}", (20 + i % 50).to_s, "person#{i}@example.com", (i % 2 == 0).to_s] }
      ),

      # Empty file for testing
      "empty_file.xlsx" => [["Name", "Age"]],

      # Header mismatch
      "header_mismatch.xlsx" => [
        ["Wrong Header", "Another Wrong", "Third Wrong"],
        ["Data 1", "Data 2", "Data 3"]
      ],

      # Special characters in data
      "special_characters.xlsx" => [
        ["Name", "Description", "Active"],
        ["José María", "Special chars: àáâã & ñü", "true"],
        ["测试用户", "Unicode: ♦ ♣ ♠ ♥", "false"]
      ],

      # Edge case edge_case_test pattern for background processing
      "edge_case_base.xlsx" => [
        ["Name", "Age", "Email", "Active"],
        ["Test User", "30", "test@example.com", "true"]
      ],

      # Large dataset with validation failures
      "large_dataset_with_validation_errors.xlsx" => ([["Name", "Age", "Active"]] + 
        (0..99).map do |i|
          case i % 4
          when 0
            ["", i.to_s, "true"] # Missing required name
          when 1  
            ["User #{i}", "not_a_number", "true"] # Invalid number
          when 2
            ["User #{i}", i.to_s, "maybe"] # Invalid boolean  
          when 3
            ["User #{i}", i.to_s, "true"] # Valid row
          end
        end
      ),

      # Wide spreadsheet for memory testing
      "very_wide_spreadsheet.xlsx" => [
        (1..100).map { |i| "Column #{i}" },
        (1..100).map { |i| "Data #{i}" }
      ],

      # Data guaranteed to fail validation for error consistency tests
      "problematic_validation_data.xlsx" => [
        ["Name", "Age", "Active"],
        ["", "invalid", "maybe"], # Multiple validation issues
        ["Valid User", "25", "true"], # This one should be valid but transaction will roll back
        ["Another Bad", "also_invalid", "perhaps"] # More issues
      ]
    }

    excel_templates.each do |filename, data|
      puts "Creating #{filename}..."
      
      package = Axlsx::Package.new
      workbook = package.workbook
      worksheet = workbook.add_worksheet(name: "Test Data")
      
      data.each { |row| worksheet.add_row(row) }
      
      file_path = fixtures_dir.join(filename)
      package.serialize(file_path)
      
      puts "✓ Created #{file_path}"
    end

    # Create some corrupted files for error testing
    corrupted_files = {
      "corrupted_file.xlsx" => "This is not a valid Excel file content",
      "wrong_mime_type.txt" => "Plain text file with wrong extension"
    }

    corrupted_files.each do |filename, content|
      file_path = fixtures_dir.join(filename)
      File.write(file_path, content)
      puts "✓ Created corrupted file #{file_path}"
    end

    puts "\n✅ All Excel fixture files generated successfully!"
    puts "Files created in: #{fixtures_dir}"
  end
end