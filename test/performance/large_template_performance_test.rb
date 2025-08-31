# frozen_string_literal: true

require "test_helper"

class LargeTemplatePerformanceTest < ActiveSupport::TestCase
  include Devise::Test::IntegrationHelpers

  def setup
    @user = users(:one)
  end

  test "template with 50 columns performs within acceptable limits" do
    template = nil
    
    creation_time = Benchmark.realtime do
      template = ImportTemplate.create!(
        name: "Large 50 cols",
        description: "Performance test template with 50 columns",
        user: @user
      )
      
      (1..50).each do |i|
        template.template_columns.create!(
          name: "Column #{i}",
          data_type: %w[string number date boolean].sample,
          column_number: i,
          required: false
        )
      end
    end
    
    assert template.template_columns.count == 50, "Template should have 50 columns"
    assert creation_time < 5.0, "Template creation should complete within 5 seconds, took #{creation_time.round(2)}s"
  end

  test "data record creation with 50 columns performs within acceptable limits" do
    template = create_large_template(50)
    
    creation_time = Benchmark.realtime do
      data_record = template.data_records.build
      
      template.template_columns.each do |column|
        value = case column.data_type
                when "string"
                  "Sample text for #{column.name}"
                when "number"
                  rand(1..1000)
                when "date"
                  Date.current
                when "boolean"
                  [true, false].sample
                end
        
        data_record.set_value_for_column(column, value)
      end
      
      data_record.save!
    end
    
    assert creation_time < 3.0, "Data record creation should complete within 3 seconds, took #{creation_time.round(2)}s"
  end

  test "excel export with 50 columns and 100 records performs within acceptable limits" do
    template = create_large_template(50)
    create_large_dataset(template, 100)
    
    export_time = Benchmark.realtime do
      service = ExcelExportService.new(template)
      package = service.generate_data_file
      
      # Verify package was created
      assert package.is_a?(Axlsx::Package), "Export should generate Axlsx package"
      assert package.workbook.worksheets.first.rows.count > 100, "Should have header + 100 data rows"
    end
    
    assert export_time < 10.0, "Excel export should complete within 10 seconds, took #{export_time.round(2)}s"
  end

  test "excel import with 50 columns and 100 records performs within acceptable limits" do
    template = create_large_template(50)
    
    # Create a test Excel file with proper format (including hidden ID column)
    workbook = Axlsx::Package.new
    worksheet = workbook.workbook.add_worksheet(name: "Data")
    
    # Add headers with ID column first (matching export format)
    headers = ["__record_id"] + template.template_columns.ordered.map(&:name)
    worksheet.add_row(headers)
    
    # Add 100 rows of sample data
    100.times do |i|
      row_data = [""] # Empty ID for new records
      row_data += template.template_columns.ordered.map do |column|
        case column.data_type
        when "string"
          "Sample #{i + 1} for #{column.name}"
        when "number"
          rand(1..1000)
        when "date"
          (Date.current - rand(0..365)).strftime("%Y-%m-%d")
        when "boolean"
          [true, false].sample.to_s
        else
          "Sample value #{i + 1}"
        end
      end
      worksheet.add_row(row_data)
    end
    
    # Create uploaded file object
    temp_file = Tempfile.new(["large_test_import", ".xlsx"])
    temp_file.binmode
    temp_file.write(workbook.to_stream.string)
    temp_file.rewind
    
    uploaded_file = ActionDispatch::Http::UploadedFile.new(
      tempfile: temp_file,
      filename: "large_test_import.xlsx",
      type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    )
    
    import_time = Benchmark.realtime do
      service = ExcelImportService.new(uploaded_file, template)
      result = service.process_import
      
      assert result.success, "Import should succeed: #{result.errors.join('; ')}"
    end
    
    assert import_time < 15.0, "Excel import should complete within 15 seconds, took #{import_time.round(2)}s"
    assert template.data_records.count == 100, "Should have imported 100 records"
    
    # Clean up
    temp_file.close
    temp_file.unlink
  end

  test "template with 100 columns still performs acceptably" do
    template = nil
    
    creation_time = Benchmark.realtime do
      template = ImportTemplate.create!(
        name: "XL 100 cols",
        description: "Performance test template with 100 columns",
        user: @user
      )
      
      (1..100).each do |i|
        template.template_columns.create!(
          name: "Column #{i}",
          data_type: %w[string number date boolean].sample,
          column_number: i,
          required: false
        )
      end
    end
    
    assert template.template_columns.count == 100, "Template should have 100 columns"
    assert creation_time < 10.0, "Large template creation should complete within 10 seconds, took #{creation_time.round(2)}s"
    
    # Test single record creation
    record_time = Benchmark.realtime do
      data_record = template.data_records.build
      
      template.template_columns.limit(10).each do |column|
        value = case column.data_type
                when "string"
                  "Test value"
                when "number"
                  100
                when "date"
                  Date.current
                when "boolean"
                  true
                end
        
        data_record.set_value_for_column(column, value)
      end
      
      data_record.save!
    end
    
    assert record_time < 2.0, "Single record creation should complete within 2 seconds, took #{record_time.round(2)}s"
  end

  test "database queries remain efficient with large column counts" do
    template = create_large_template(75)
    create_large_dataset(template, 50)
    
    # Test loading template with all columns
    query_time = Benchmark.realtime do
      loaded_template = ImportTemplate.includes(:template_columns).find(template.id)
      assert loaded_template.template_columns.loaded?, "Template columns should be loaded"
      assert loaded_template.template_columns.count == 75, "Should load all 75 columns"
    end
    
    assert query_time < 1.0, "Template loading should complete within 1 second, took #{query_time.round(2)}s"
    
    # Test loading data records with values
    query_time = Benchmark.realtime do
      records = template.data_records.includes(data_record_values: :template_column).limit(10)
      records.each do |record|
        assert record.data_record_values.loaded?, "Values should be loaded"
        # Access first few values to trigger loading
        record.data_record_values.limit(5).each(&:value)
      end
    end
    
    assert query_time < 2.0, "Data records loading should complete within 2 seconds, took #{query_time.round(2)}s"
  end

  private

  def create_large_template(column_count)
    template = ImportTemplate.create!(
      name: "Perf Test #{column_count}",
      description: "Template for performance testing with #{column_count} columns",
      user: @user
    )
    
    (1..column_count).each do |i|
      template.template_columns.create!(
        name: "Column #{i}",
        data_type: %w[string number date boolean].sample,
        column_number: i,
        required: false # No required fields for performance testing
      )
    end
    
    template
  end

  def create_large_dataset(template, record_count)
    record_count.times do |i|
      data_record = template.data_records.build
      
      # Only populate first 10 columns to keep test reasonable
      template.template_columns.limit(10).each do |column|
        value = case column.data_type
                when "string"
                  "Record #{i + 1} - #{column.name}"
                when "number"
                  (i + 1) * rand(1..10)
                when "date"
                  Date.current - rand(0..365)
                when "boolean"
                  i.even?
                end
        
        data_record.set_value_for_column(column, value)
      end
      
      data_record.save!
    end
  end
end