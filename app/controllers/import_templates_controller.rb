class ImportTemplatesController < ApplicationController
  before_action :set_import_template, only: %i[show edit update destroy data_records]

  def index
    @import_templates = ImportTemplate.all.order(:name)
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

  private

  def set_import_template
    @import_template = ImportTemplate.find(params[:id])
  end

  def import_template_params
    params.require(:import_template).permit(:name, :description, column_definitions: {})
  end
end
