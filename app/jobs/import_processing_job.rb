# frozen_string_literal: true

class ImportProcessingJob < ApplicationJob
  queue_as :default

  def perform(import_template_id, job_id, file_path)
    # Update status to processing at job start
    JobStatusService.update_status(job_id, :processing, started_at: Time.current)

    # Load the import template
    import_template = ImportTemplate.find(import_template_id)

    # Create ActionDispatch::Http::UploadedFile from file_path for service compatibility
    uploaded_file = ActionDispatch::Http::UploadedFile.new(
      tempfile: File.open(file_path),
      filename: File.basename(file_path),
      type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    )

    # Call existing ExcelImportService unchanged
    service_result = ExcelImportService.new(uploaded_file, import_template).process_import

    # Update job status based on service result
    if service_result.success
      JobStatusService.update_status(job_id, :completed,
                                     completed_at: Time.current,
                                     result_summary: service_result.summary,
                                     processed_count: service_result.processed_count)
    else
      JobStatusService.update_status(job_id, :failed,
                                     completed_at: Time.current,
                                     error_message: service_result.errors.join("; "))
    end
  rescue StandardError => e
    JobStatusService.update_status(job_id, :failed,
                                   completed_at: Time.current,
                                   error_message: e.message)
  ensure
    # Clean up temporary file
    File.delete(file_path) if File.exist?(file_path)
  end
end
