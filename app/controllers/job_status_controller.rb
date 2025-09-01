# frozen_string_literal: true

class JobStatusController < ApplicationController
  before_action :authenticate_user!, except: [:status]
  before_action :set_import_template_and_job_id, except: [:status]

  def show
    @job_id = params[:id]
    @import_template = ImportTemplate.find(params[:import_template_id])
    @status_data = JobStatusService.get_status(@job_id)

    # Handle case where job status is not found
    if @status_data[:status] == :not_found
      redirect_to @import_template, alert: "Job status not found. The job may have expired or never existed."
      return
    end

    respond_to do |format|
      format.html # Regular job status page
      format.json { render json: @status_data } # API endpoint for polling/debugging
    end
  end

  # API endpoint for polling/debugging: GET /jobs/:job_id/status.json
  def status
    @job_id = params[:id]

    begin
      @status_data = JobStatusService.get_status(@job_id)
    rescue StandardError => e
      Rails.logger.error "Error getting job status for #{@job_id}: #{e.message}"
      @status_data = { status: :error, error: "Unable to retrieve job status" }
    end

    render json: @status_data
  end

  private

  def set_import_template_and_job_id
    @import_template = current_user.import_templates.find(params[:import_template_id])
    @job_id = params[:id]
  rescue ActiveRecord::RecordNotFound
    redirect_to import_templates_path, alert: "Import template not found."
  end
end
