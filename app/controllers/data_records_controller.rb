# frozen_string_literal: true

class DataRecordsController < ApplicationController
  before_action :set_import_template
  before_action :set_data_record, only: %i[show edit update destroy]

  def index
    @data_records = @import_template.data_records.order(created_at: :desc)
  end

  def show; end

  def new
    @data_record = @import_template.data_records.build
  end

  def edit; end

  def create
    @data_record = @import_template.data_records.build(data_record_params)

    if @data_record.save
      redirect_to [@import_template, @data_record], notice: "Record was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @data_record.update(data_record_params)
      redirect_to [@import_template, @data_record], notice: "Record was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @data_record.destroy
    redirect_to import_template_data_records_path(@import_template), notice: "Record was successfully deleted."
  end

  private

  def set_import_template
    @import_template = current_user.import_templates.find(params[:import_template_id] || params[:id])
  end

  def set_data_record
    @data_record = @import_template.data_records.find(params[:id])
  end

  def data_record_params
    params.expect(data_record: %i[column_1 column_2 column_3 column_4 column_5 import_batch_id])
  end
end
