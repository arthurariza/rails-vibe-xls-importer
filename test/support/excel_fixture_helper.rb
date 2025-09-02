# frozen_string_literal: true

module ExcelFixtureHelper
  # Returns the path to a fixture Excel file
  def excel_fixture_path(filename)
    Rails.root.join("test/fixtures/files", filename)
  end

  # Creates an ActionDispatch::Http::UploadedFile from a fixture Excel file
  def uploaded_excel_fixture(filename, original_filename: nil)
    file_path = excel_fixture_path(filename)
    original_filename ||= filename
    
    # Open the file and create a copy to avoid file locking issues in parallel tests
    temp_file = Tempfile.new([File.basename(filename, ".*"), File.extname(filename)])
    temp_file.binmode
    temp_file.write(File.binread(file_path))
    temp_file.rewind

    ActionDispatch::Http::UploadedFile.new(
      tempfile: temp_file,
      filename: original_filename,
      type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    )
  end

  # Creates a customized Excel file based on a fixture, replacing placeholders with actual values
  # This is for tests that need specific record IDs from the database
  def customized_excel_fixture(base_filename, replacements = {})
    require "caxlsx"
    require "roo"
    
    # Read the base fixture file
    file_path = excel_fixture_path(base_filename)
    
    # Use Roo to read the Excel file
    workbook = Roo::Excelx.new(file_path.to_s)
    sheet = workbook.sheet(workbook.default_sheet)
    
    # Convert to array format
    data = []
    (1..sheet.last_row).each do |row_num|
      row_data = []
      (1..sheet.last_column).each do |col_num|
        cell_value = sheet.cell(row_num, col_num)
        row_data << cell_value
      end
      data << row_data
    end
    
    # Apply replacements
    data = data.map do |row|
      row.map do |cell|
        if cell.is_a?(String) && replacements.key?(cell)
          replacements[cell]
        elsif cell.is_a?(Numeric) && replacements.key?(cell)
          replacements[cell]
        else
          cell
        end
      end
    end
    
    # Create new Excel file with replaced data
    package = Axlsx::Package.new
    workbook_new = package.workbook
    worksheet = workbook_new.add_worksheet(name: "Test Data")
    
    data.each { |row| worksheet.add_row(row) }
    
    # Create temporary file
    temp_file = Tempfile.new([File.basename(base_filename, ".*"), ".xlsx"])
    temp_file.binmode
    temp_file.write(package.to_stream.string)
    temp_file.rewind
    
    ActionDispatch::Http::UploadedFile.new(
      tempfile: temp_file,
      filename: base_filename,
      type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    )
  end

  # For backward compatibility - creates a simple Excel file on demand
  # Use this only when fixture files don't cover the exact scenario
  def create_simple_excel_file(data, filename_prefix = "test")
    require "caxlsx"

    package = Axlsx::Package.new
    workbook = package.workbook
    worksheet = workbook.add_worksheet(name: "Test Data")
    data.each { |row| worksheet.add_row(row) }

    temp_file = Tempfile.new(["#{filename_prefix}_#{SecureRandom.hex(8)}", ".xlsx"])
    temp_file.binmode
    temp_file.write(package.to_stream.string)
    temp_file.rewind

    ActionDispatch::Http::UploadedFile.new(
      tempfile: temp_file,
      filename: "#{filename_prefix}.xlsx",
      type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    )
  end

  # Get path for file-based tests (when test needs actual file path instead of UploadedFile)
  def excel_fixture_file_path(filename)
    file_path = excel_fixture_path(filename)
    
    # Create a unique temporary copy to avoid parallel test conflicts
    temp_path = Rails.root.join("tmp", "test_#{SecureRandom.hex(8)}_#{filename}")
    FileUtils.mkdir_p(File.dirname(temp_path))
    FileUtils.cp(file_path, temp_path)
    
    temp_path.to_s
  end
end