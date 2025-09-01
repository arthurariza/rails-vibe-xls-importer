# frozen_string_literal: true

class ExportGenerationJob < ApplicationJob
  queue_as :default

  def perform(import_template_id, job_id, export_type = :data)
    # Update status to processing at job start
    JobStatusService.update_status(job_id, :processing, started_at: Time.current)

    # Load the import template
    import_template = ImportTemplate.find(import_template_id)

    # Call existing ExcelExportService unchanged
    service = ExcelExportService.new(import_template)
    package = case export_type.to_sym
              when :template
                service.generate_template_file
              when :sample
                service.generate_sample_file
              else
                service.generate_data_file
              end

    # Generate temporary file path for the export
    temp_file_path = Rails.root.join("tmp", "exports", "#{job_id}.xlsx")
    FileUtils.mkdir_p(File.dirname(temp_file_path))

    # Save the package to file
    package.serialize(temp_file_path)

    # Update job status to completed
    JobStatusService.update_status(job_id, :completed,
                                   completed_at: Time.current,
                                   result_summary: "Export generated successfully",
                                   file_path: temp_file_path.to_s)
  rescue StandardError => e
    JobStatusService.update_status(job_id, :failed,
                                   completed_at: Time.current,
                                   error_message: e.message)
  end
end
