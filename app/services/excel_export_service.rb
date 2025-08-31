# frozen_string_literal: true

class ExcelExportService < ApplicationService
  attr_reader :import_template

  def initialize(import_template)
    @import_template = import_template
  end

  def generate_template_file
    create_workbook do |sheet|
      add_headers(sheet)
    end
  end

  def generate_data_file
    create_workbook do |sheet|
      add_headers(sheet)
      add_data_rows(sheet)
    end
  end

  def generate_sample_file
    create_workbook do |sheet|
      add_headers(sheet)
      add_sample_rows(sheet)
    end
  end

  private

  def create_workbook(&)
    require "caxlsx"

    package = Axlsx::Package.new
    workbook = package.workbook

    workbook.add_worksheet(name: sanitized_template_name, &)

    package
  end

  def add_headers(sheet)
    headers = import_template.column_headers
    return if headers.empty?

    # Add hidden ID column as first column, followed by user-defined headers
    headers_with_id = ["__record_id"] + headers

    # Create header row with styling
    sheet.add_row(headers_with_id, style: header_style(sheet))

    # Hide the ID column from users (column A)
    sheet.column_info.first.hidden = true
    sheet.column_info.first.width = 0.1
  end

  def add_data_rows(sheet)
    import_template.data_records.find_each do |record|
      row_data = build_row_data(record)
      sheet.add_row(row_data)
    end
  end

  def add_sample_rows(sheet)
    3.times do |i|
      sample_data = build_sample_row_data(i + 1)
      sheet.add_row(sample_data)
    end
  end

  def build_row_data(record)
    # Start with record ID as first column
    row_data = [record.id]

    # Add user-defined column data
    (1..5).each do |col_num|
      column_def = import_template.column_definition(col_num)
      next if column_def.blank?

      row_data << format_cell_value(record.column_value(col_num), column_def["data_type"])
    end

    row_data
  end

  def build_sample_row_data(row_number)
    # Start with placeholder ID (empty for sample data since these aren't real records)
    row_data = [""]

    # Add sample data for user-defined columns
    (1..5).each do |col_num|
      column_def = import_template.column_definition(col_num)
      next if column_def.blank?

      row_data << generate_sample_value(column_def, row_number)
    end

    row_data
  end

  def format_cell_value(value, data_type)
    return "" if value.blank?

    case data_type
    when "number"
      value.to_f
    when "date"
      begin
        Date.parse(value)
      rescue StandardError
        value
      end
    when "boolean"
      value == "true"
    else
      value.to_s
    end
  end

  def generate_sample_value(column_def, row_number)
    case column_def["data_type"]
    when "string"
      "Sample #{column_def['name']} #{row_number}"
    when "number"
      (row_number * 100).to_f
    when "date"
      Date.current + row_number.days
    when "boolean"
      row_number.odd?
    else
      "Sample value #{row_number}"
    end
  end

  def header_style(sheet)
    # Create styles for headers
    hidden_style = sheet.styles.add_style(
      bg_color: "F2F2F2",
      fg_color: "666666",
      sz: 8,
      b: false
    )

    visible_style = sheet.styles.add_style(
      bg_color: "4472C4",
      fg_color: "FFFFFF",
      sz: 12,
      b: true,
      alignment: { horizontal: :center }
    )

    # Return array of styles: hidden style for ID column, visible style for user columns
    [hidden_style] + Array.new(import_template.column_headers.length, visible_style)
  end

  def sanitized_template_name
    import_template.name.gsub(/[^\w\s-]/, "").strip.gsub(/\s+/, "_")
  end
end
