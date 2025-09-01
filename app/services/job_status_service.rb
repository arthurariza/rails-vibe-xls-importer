# frozen_string_literal: true

class JobStatusService < ApplicationService
  def self.cache_key(job_id)
    "job_status:#{job_id}"
  end

  def self.get_status(job_id)
    Rails.cache.read(cache_key(job_id)) || { status: :not_found }
  rescue StandardError => e
    Rails.logger.error("JobStatusService cache read error for job_id #{job_id}: #{e.message}")
    { status: :error, error_message: "Cache read failed" }
  end

  def self.update_status(job_id, status, **additional_data)
    current_data = get_status(job_id)
    updated_data = current_data.merge(
      status: status,
      updated_at: Time.current,
      **additional_data
    )

    Rails.cache.write(cache_key(job_id), updated_data, expires_in: 24.hours)
    broadcast_status_change(job_id, updated_data)
    updated_data
  rescue StandardError => e
    Rails.logger.error("JobStatusService cache write error for job_id #{job_id}: #{e.message}")
    # Return the intended data even if cache write fails
    updated_data || { status: :error, error_message: "Cache write failed" }
  end

  def self.update_progress(job_id, progress_message)
    update_status(job_id, :processing, progress: progress_message)
  end

  def self.broadcast_status_change(job_id, status_data)
    Turbo::StreamsChannel.broadcast_replace_to(
      "job_status_#{job_id}",
      target: "job_status_#{job_id}",
      partial: "shared/job_status",
      locals: { job_id: job_id, status_data: status_data }
    )
  rescue StandardError => e
    Rails.logger.error("JobStatusService broadcast error for job_id #{job_id}: #{e.message}")
    # Don't re-raise as broadcast failure shouldn't break the job status update
  end
end
