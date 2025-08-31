# frozen_string_literal: true

class TemplateColumnsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_import_template
  before_action :set_template_column, only: %i[update destroy]

  def create
    @template_column = @import_template.template_columns.build(template_column_params)

    if @template_column.save
      render json: {
        status: "success",
        column: {
          id: @template_column.id,
          name: @template_column.name,
          data_type: @template_column.data_type,
          required: @template_column.required,
          column_number: @template_column.column_number
        }
      }
    else
      render json: {
        status: "error",
        errors: @template_column.errors.full_messages
      }, status: :unprocessable_content
    end
  end

  def update
    if @template_column.update(template_column_params)
      render json: {
        status: "success",
        column: {
          id: @template_column.id,
          name: @template_column.name,
          data_type: @template_column.data_type,
          required: @template_column.required,
          column_number: @template_column.column_number
        }
      }
    else
      render json: {
        status: "error",
        errors: @template_column.errors.full_messages
      }, status: :unprocessable_content
    end
  end

  def destroy
    if @template_column.destroy
      # Reorder remaining columns after deletion
      @import_template.reorder_columns

      render json: {
        status: "success",
        message: "Column deleted successfully"
      }
    else
      render json: {
        status: "error",
        errors: ["Failed to delete column"]
      }, status: :unprocessable_content
    end
  end

  private

  def set_import_template
    @import_template = current_user.import_templates.find(params[:import_template_id])
  rescue ActiveRecord::RecordNotFound
    render json: {
      status: "error",
      errors: ["Import template not found"]
    }, status: :not_found
  end

  def set_template_column
    @template_column = @import_template.template_columns.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: {
      status: "error",
      errors: ["Column not found"]
    }, status: :not_found
  end

  def template_column_params
    params.expect(template_column: %i[name data_type required column_number])
  end
end
