## Relevant Files

- `db/migrate/add_background_processing_to_import_templates.rb` - Migration to add status enum and processing fields to ImportTemplate model
- `app/models/import_template.rb` - Add status enum, timestamps, and Turbo Stream broadcasting callbacks
- `app/jobs/import_processing_job.rb` - Background job for processing XLS imports using Solid Queue
- `app/jobs/export_generation_job.rb` - Background job for generating XLS exports using Solid Queue  
- `app/controllers/import_templates_controller.rb` - Modify create action to enqueue background job and redirect to status page
- `app/views/import_templates/show.html.erb` - Job status page with real-time updates via Turbo Streams
- `app/views/shared/_job_status.html.erb` - Reusable partial for displaying job status information
- `app/javascript/controllers/job_status_controller.js` - Stimulus controller for job status page interactions (following Hotwire patterns)
- `app/services/excel_import_service.rb` - Modify to return proper result objects for background job consumption
- `test/jobs/import_processing_job_test.rb` - Unit tests for import background job
- `test/jobs/export_generation_job_test.rb` - Unit tests for export background job
- `test/models/import_template_test.rb` - Tests for new status enum and broadcasting behavior
- `test/controllers/import_templates_controller_test.rb` - Tests for background job enqueueing and redirection
- `test/system/background_processing_test.rb` - System tests using Playwright MCP for real-time status updates

## Tasks

- [ ] 1.0 Add Background Processing Fields to ImportTemplate Model (including tests)
  - [ ] 1.1 Generate migration to add status enum (:pending, :processing, :completed, :failed) to import_templates table
  - [ ] 1.2 Add processing_started_at and processing_completed_at timestamp columns to migration
  - [ ] 1.3 Add error_message text column and background_job_id string column to migration
  - [ ] 1.4 Run migration and verify schema changes
  - [ ] 1.5 Add status enum definition to ImportTemplate model with default :pending
  - [ ] 1.6 Add after_update callback to broadcast Turbo Stream updates when status changes
  - [ ] 1.7 Add helper methods for status checks (pending?, processing?, completed?, failed?)
  - [ ] 1.8 Write unit tests for status enum behavior and transitions
  - [ ] 1.9 Write unit tests for Turbo Stream broadcasting when status changes
  - [ ] 1.10 Update existing ImportTemplate fixtures with new fields for consistent testing

- [ ] 2.0 Create Background Jobs for Import and Export Processing (including tests)
  - [ ] 2.1 Generate ImportProcessingJob class inheriting from ApplicationJob
  - [ ] 2.2 Implement perform method that updates ImportTemplate status to :processing at start
  - [ ] 2.3 Call existing ExcelImportService.new(file, import_template).process_import
  - [ ] 2.4 Update ImportTemplate status to :completed/:failed based on service result
  - [ ] 2.5 Handle broadcasting of status changes through model callbacks (no manual broadcasting in jobs)
  - [ ] 2.6 Generate ExportGenerationJob class with similar structure calling existing export service
  - [ ] 2.7 Ensure jobs focus only on status management and service orchestration
  - [ ] 2.8 Write unit tests for ImportProcessingJob status updates and service integration
  - [ ] 2.9 Write unit tests for ExportGenerationJob with mocked service calls
  - [ ] 2.10 Test that jobs properly delegate to existing services without duplicating logic

- [ ] 3.0 Modify Controllers to Use Background Processing (including tests)
  - [ ] 3.1 Update ImportTemplatesController#create to enqueue ImportProcessingJob instead of processing synchronously
  - [ ] 3.2 Create ImportTemplate record with status :pending before job enqueueing
  - [ ] 3.3 Store background_job_id from Solid Queue job enqueueing response
  - [ ] 3.4 Redirect to import_template_path(template) (show page) after successful enqueueing
  - [ ] 3.5 Add error handling for job enqueueing failures
  - [ ] 3.6 Update strong parameters to handle background processing fields if needed
  - [ ] 3.7 Modify any export controllers to use ExportGenerationJob similarly
  - [ ] 3.8 Write controller tests verifying job enqueueing instead of synchronous processing
  - [ ] 3.9 Test proper redirection to status page after job enqueueing
  - [ ] 3.10 Test error handling when job enqueueing fails

- [ ] 4.0 Implement Real-time Status Updates with Turbo Streams and Hotwire (including Playwright system tests)
  - [ ] 4.1 Create app/views/shared/_job_status.html.erb partial for displaying job status
  - [ ] 4.2 Add status indicators with appropriate styling (pending/processing/completed/failed states)
  - [ ] 4.3 Include Turbo Stream target elements with job-specific IDs for broadcasting
  - [ ] 4.4 Update import_templates/show.html.erb to use job_status partial
  - [ ] 4.5 Add turbo_stream_from helper to subscribe to job status updates
  - [ ] 4.6 Create Stimulus controller (job_status_controller.js) following Hotwire patterns
  - [ ] 4.7 Implement auto-refresh functionality and progress indication using Stimulus values/targets
  - [ ] 4.8 Add error state display with clear error messages from job failures
  - [ ] 4.9 Test Turbo Stream broadcasting integration with model callbacks
  - [ ] 4.10 Write Playwright system tests to verify real-time status updates work end-to-end
  - [ ] 4.11 Use Playwright MCP to test file upload → job status page → real-time updates flow
  - [ ] 4.12 Test error scenarios and ensure proper error display using Playwright automation

- [ ] 5.0 Update Services to Support Background Job Integration (including tests)
  - [ ] 5.1 Verify ExcelImportService.process_import returns proper result objects with success/failure status
  - [ ] 5.2 Ensure ImportResult class has proper success boolean and error_message fields
  - [ ] 5.3 Verify service error handling provides meaningful error messages for job consumption
  - [ ] 5.4 Confirm ExcelExportService follows similar result object pattern
  - [ ] 5.5 Test that existing services work unchanged when called from background jobs
  - [ ] 5.6 Update service unit tests to verify result object structure if needed
  - [ ] 5.7 Test edge cases like file validation failures and processing exceptions
  - [ ] 5.8 Ensure services remain fully synchronous-compatible for any non-background use cases
  - [ ] 5.9 Verify service performance with larger files suitable for background processing
  - [ ] 5.10 Document any service method changes required for background job integration