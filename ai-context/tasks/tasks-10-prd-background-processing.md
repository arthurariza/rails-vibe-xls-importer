## Relevant Files

- `app/services/job_status_service.rb` - Service for managing cache-based job status tracking and Turbo Stream broadcasting
- `app/jobs/import_processing_job.rb` - Background job for processing XLS imports using Solid Queue with cache-based status updates
- `app/jobs/export_generation_job.rb` - Background job for generating XLS exports using Solid Queue with cache-based status updates
- `app/controllers/import_templates_controller.rb` - Modify import_file action to save temp file, enqueue job, and redirect to status page
- `app/controllers/job_status_controller.rb` - New controller for job status pages and status API endpoints
- `app/views/job_status/show.html.erb` - Job status page with real-time updates via Turbo Streams
- `app/views/shared/_job_status.html.erb` - Reusable partial for displaying job status information from cache
- `app/javascript/controllers/job_status_controller.js` - Stimulus controller for job status page interactions (following Hotwire patterns)
- `config/routes.rb` - Add routes for job status pages: `/import_templates/:template_id/jobs/:job_id`
- `test/services/job_status_service_test.rb` - Unit tests for cache-based status tracking and broadcasting
- `test/jobs/import_processing_job_test.rb` - Unit tests for import background job with cache status integration
- `test/jobs/export_generation_job_test.rb` - Unit tests for export background job with cache status integration
- `test/controllers/job_status_controller_test.rb` - Tests for job status pages and API endpoints
- `test/controllers/import_templates_controller_test.rb` - Tests for background job enqueueing and redirection
- `test/system/background_processing_test.rb` - System tests using Playwright MCP for real-time status updates

## Tasks

- [x] 1.0 Create JobStatusService for Cache-Based Status Tracking (including tests)
  - [x] 1.1 Generate JobStatusService class inheriting from ApplicationService
  - [x] 1.2 Implement cache_key method for consistent key generation: "job_status:#{job_id}"
  - [x] 1.3 Implement get_status method to read job status from Rails.cache
  - [x] 1.4 Implement update_status method to write status updates to cache with 24-hour expiration
  - [x] 1.5 Implement update_progress method for optional progress message updates
  - [x] 1.6 Implement broadcast_status_change private method for Turbo Stream broadcasting
  - [x] 1.7 Add proper error handling for cache read/write operations
  - [x] 1.8 Write unit tests for cache operations and status transitions
  - [x] 1.9 Write unit tests for Turbo Stream broadcasting integration
  - [x] 1.10 Test cache expiration behavior and auto-cleanup functionality

- [x] 2.0 Create Background Jobs with Cache-Based Status Integration (including tests)
  - [x] 2.1 Generate ImportProcessingJob class inheriting from ApplicationJob
  - [x] 2.2 Implement perform method accepting (import_template_id, job_id, file_path) parameters
  - [x] 2.3 Update job status to :processing using JobStatusService.update_status at job start
  - [x] 2.4 Create ActionDispatch::Http::UploadedFile from file_path for service compatibility
  - [x] 2.5 Call existing ExcelImportService.new(file, import_template).process_import unchanged
  - [x] 2.6 Update job status to :completed/:failed based on service result using JobStatusService
  - [x] 2.7 Add proper error handling and ensure block for temporary file cleanup
  - [x] 2.8 Generate ExportGenerationJob class with similar cache-based status structure
  - [x] 2.9 Write unit tests for ImportProcessingJob cache status integration and service delegation
  - [x] 2.10 Write unit tests for ExportGenerationJob with mocked service calls and cache verification

- [x] 3.0 Modify Controllers for Background Processing with File Handling (including tests)
  - [x] 3.1 Update ImportTemplatesController#import_file to save uploaded file to temporary location
  - [x] 3.2 Generate unique job_id using SecureRandom.hex(8) for cache key generation
  - [x] 3.3 Initialize job status in cache using JobStatusService.update_status with :pending status
  - [x] 3.4 Enqueue ImportProcessingJob with (template_id, job_id, file_path) parameters
  - [x] 3.5 Redirect to job status page: /import_templates/:template_id/jobs/:job_id
  - [x] 3.6 Add error handling for file saving and job enqueueing failures
  - [x] 3.7 Create JobStatusController with show action for job status pages
  - [x] 3.8 Add job status API endpoint for polling/debugging: GET /jobs/:job_id/status.json
  - [x] 3.9 Write controller tests verifying file handling, job enqueueing, and status page redirection
  - [x] 3.10 Test error handling for invalid files, job failures, and missing job status

- [ ] 4.0 Implement Real-time Status Updates with Cache-Based Turbo Streams (use Playwright Mcp If needed)
  - [ ] 4.1 Create app/views/shared/_job_status.html.erb partial accepting job_id and status_data locals
  - [ ] 4.2 Add status indicators with appropriate styling (pending/processing/completed/failed states)
  - [ ] 4.3 Include Turbo Stream target elements with job-specific IDs: id="job_status_#{job_id}"
  - [ ] 4.4 Create app/views/job_status/show.html.erb for dedicated job status pages
  - [ ] 4.5 Add turbo_stream_from "job_status_#{@job_id}" helper to subscribe to updates
  - [ ] 4.6 Add routes for job status pages: resources :import_templates do resources :jobs, only: [:show]
  - [ ] 4.7 Create Stimulus controller (job_status_controller.js) for client-side interactions
  - [ ] 4.8 Implement fallback polling mechanism for browsers without Turbo Stream support
  - [ ] 4.9 Add error state display with clear error messages from cache-stored job failures
  - [ ] 4.10 Test Turbo Stream broadcasting integration with JobStatusService

- [ ] 5.0 Verify Service Integration Compatibility (no changes required)
  - [ ] 5.1 Confirm ExcelImportService.process_import already returns proper ImportResult objects
  - [ ] 5.2 Verify ImportResult class has success boolean and errors array structure for job consumption
  - [ ] 5.3 Test existing service error handling provides meaningful error messages for cache storage
  - [ ] 5.4 Confirm ExcelExportService follows similar result object pattern for background jobs
  - [ ] 5.5 Test that services work unchanged when called from background jobs with file parameter
  - [ ] 5.6 Verify service compatibility with ActionDispatch::Http::UploadedFile created from temp files
  - [ ] 5.7 Test edge cases like file validation failures and processing exceptions in background context
  - [ ] 5.8 Ensure services remain fully synchronous-compatible for non-background use cases
  - [ ] 5.9 Document service result object expectations for background job integration