# frozen_string_literal: true

class ImportTemplatesController < ApplicationController
  before_action :set_import_template,
                only: %i[show edit update destroy data_records export_template export_data export_sample import_form
                         import_file]

  def index
    @import_templates = ImportTemplate.order(:name)
  end

  def show
    @data_records = @import_template.data_records.limit(10)
    @data_records_count = @import_template.data_records.count
  end

  def new
    @import_template = ImportTemplate.new
  end

  def edit; end

  def create
    @import_template = ImportTemplate.new(import_template_params)

    if @import_template.save
      redirect_to @import_template, notice: "Template was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @import_template.update(import_template_params)
      redirect_to @import_template, notice: "Template was successfully updated."
    else
      render :edit, status: :unprocessable_entity
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
    if params[:excel_file].blank?
      redirect_to import_form_import_template_path(@import_template),
                  alert: "Please select a file to import."
      return
    end

    service = ExcelImportService.new(params[:excel_file], @import_template)
    @import_result = service.process_import

    if @import_result.success
      redirect_to @import_template,
                  notice: @import_result.summary
    else
      flash.now[:alert] = "Synchronization failed with errors:"
      render :import_result
    end
  end

  private

  def set_import_template
    @import_template = ImportTemplate.find(params[:id])
  end

  def import_template_params
    params.expect(import_template: [:name, :description, { column_definitions: {} }])
  end

  def sanitize_filename(filename)
    filename.gsub(/[^\w\s-]/, "").strip.gsub(/\s+/, "_")
  end
end
