# frozen_string_literal: true

class ImportTemplatesController < ApplicationController
  before_action :set_import_template,
                only: %i[show edit update destroy data_records export_template export_data export_sample import_form
                         import_file]

  def index
    @import_templates = current_user.import_templates.order(:name)
  end

  def show
    @data_records = @import_template.data_records.limit(10)
    @data_records_count = @import_template.data_records.count
  end

  def new
    @import_template = current_user.import_templates.build
  end

  def edit; end

  def create
    @import_template = current_user.import_templates.build(import_template_params)

    if @import_template.save
      handle_template_columns
      redirect_to @import_template, notice: "Template was successfully created."
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @import_template.update(import_template_params)
      handle_template_columns
      redirect_to @import_template, notice: "Template was successfully updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @import_template.destroy
    redirect_to import_templates_url, notice: "Template was successfully deleted."
  end

  def data_records
    @data_records = @import_template.data_records.order(created_at: :desc)
  end

  def export_template
    service = ExcelExportService.new(@import_template)
    package = service.generate_template_file

    send_data package.to_stream.read,
              filename: "#{sanitize_filename(@import_template.name)}_template.xlsx",
              type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
  end

  def export_data
    service = ExcelExportService.new(@import_template)
    package = service.generate_data_file

    send_data package.to_stream.read,
              filename: "#{sanitize_filename(@import_template.name)}_data.xlsx",
              type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
  end

  def export_sample
    service = ExcelExportService.new(@import_template)
    package = service.generate_sample_file

    send_data package.to_stream.read,
              filename: "#{sanitize_filename(@import_template.name)}_sample.xlsx",
              type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
  end

  def import_form
    # Just render the import form
  end

  def import_file
    return redirect_with_error("Please select a file to import.") if params[:excel_file].blank?

    process_excel_import
  end

  private

  def process_excel_import
    service = ExcelImportService.new(params[:excel_file], @import_template)
    @import_result = service.process_import

    if @import_result.success
      redirect_to @import_template, notice: @import_result.summary
    else
      redirect_with_error("Synchronization failed with errors: #{@import_result.errors.join(', ')}")
    end
  end

  def redirect_with_error(message)
    redirect_to import_form_import_template_path(@import_template), alert: message
  end

  def set_import_template
    @import_template = current_user.import_templates.find(params[:id])
  end

  def import_template_params
    params.expect(import_template: %i[name description])
  end

  def template_columns_params
    params.fetch(:template_columns, {})
  end

  def handle_template_columns
    return unless params[:template_columns].present?

    template_columns_params.each do |key, column_attrs|
      if key.to_s.start_with?("new_")
        # Create new column
        @import_template.template_columns.create!(column_attrs.except(:id))
      elsif column_attrs[:id].present?
        # Update existing column
        column = @import_template.template_columns.find(column_attrs[:id])
        column.update!(column_attrs.except(:id))
      end
    end

    # Reorder columns to ensure sequential numbering
    @import_template.reorder_columns
  end

  def sanitize_filename(filename)
    filename.gsub(/[^\w\s-]/, "").strip.gsub(/\s+/, "_")
  end
end
