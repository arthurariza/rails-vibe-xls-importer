# 10 - Background Processing with Solid Queue and Cache-Based Status Tracking

## Introduction/Overview

This feature introduces asynchronous background processing for time-intensive operations in the XLS Importer application. Currently, file imports and exports are processed synchronously, causing UI blocking, potential timeouts with large files, and poor user experience. By implementing Solid Queue (already included in Rails 8) with cache-based status tracking, we will move these operations to background jobs while keeping the core models clean and focused on business logic.

The feature uses Rails cache (Solid Cache) to store transient job status information, avoiding database pollution while providing real-time status updates. This approach keeps models focused on business logic while job status remains ephemeral and automatically expires.

## Goals

1. **Improve User Experience**: Enable non-blocking file imports and exports so users can continue working while processing occurs
2. **Handle Larger Files**: Support processing of larger XLS files without HTTP timeout constraints
3. **Provide Real-time Feedback**: Show live job status updates using Turbo Streams without page refreshes
4. **Ensure Reliability**: Implement proper error handling with user notifications when jobs fail
5. **Keep Models Clean**: Use cache-based status tracking to avoid polluting business models with transient job state
6. **Automatic Cleanup**: Job status automatically expires from cache, eliminating need for manual cleanup

## User Stories

1. **As a user uploading an XLS file for import**, I want to be redirected to a job status page immediately after upload, so that I know my file is being processed and can monitor progress without blocking my browser.

2. **As a user waiting for import completion**, I want to see real-time status updates (pending/processing/completed/failed) on the job status page, so that I know when my data is ready without refreshing the page.

3. **As a user whose import job fails**, I want to receive clear error notifications explaining what went wrong, so that I can understand the issue and take corrective action.

4. **As a user generating an XLS export**, I want the export to process in the background and be notified when it's ready for download, so that I don't have to wait on a loading page.

5. **As a user with multiple pending jobs**, I want to see a simple pending/completed status for each job, so that I can track all my background operations.

## Functional Requirements

### Job Processing
1. The system must queue XLS import operations in the background using Solid Queue
2. The system must queue XLS export operations in the background using Solid Queue
3. The system must process jobs using a single default queue priority
4. The system must send error notifications to users when jobs fail
5. The system must update job status in real-time using Turbo Streams and cache-based status

### Cache-Based Status Tracking
6. **Job Status Storage**: The system must store job status in Rails cache using structured keys like `job_status:import:#{resource_id}:#{job_id}`
7. **Status Structure**: Cache entries must contain structured data: `{ status: :processing, started_at: timestamp, progress: optional_progress, error_message: nil }`
8. **Cache Expiration**: Job status entries must auto-expire after 24 hours to prevent cache bloat
9. **Status Updates**: Jobs must update cache entries at key milestones without touching the database
10. **Broadcasting Integration**: Cache updates must trigger Turbo Stream broadcasts for real-time UI updates

### Job Lifecycle with Cache
11. **Job Creation**: Controller generates unique job_id and stores initial cache entry `{ status: :pending, created_at: timestamp }`
12. **Job Start**: Job updates cache to `{ status: :processing, started_at: timestamp }` and broadcasts change
13. **Job Progress**: Job can optionally update progress information in cache entry
14. **Job Completion**: Job updates cache to `{ status: :completed, completed_at: timestamp, result_data: optional }` or `{ status: :failed, completed_at: timestamp, error_message: error }`
15. **Status Retrieval**: Controllers and views read job status from cache using job_id for real-time updates

### User Interface
16. The system must redirect users to a job status page immediately after file upload with job_id in URL
17. The system must display job status as simple pending/processing/completed/failed states read from cache
18. The system must show real-time updates without requiring page refreshes via Turbo Streams
19. The system must provide clear error messages when jobs fail, stored in cache
20. The system must allow users to navigate away from job status pages and return later using job_id

### Service Integration
21. The system must integrate with existing import/export services without modifying their interfaces
22. The system must maintain existing file validation and processing logic unchanged
23. The system must work seamlessly with the current authentication system
24. The system must follow Rails job conventions from the project's rails-rules.md
25. **No Model Changes**: The system must not add any job-related fields to existing business models

## Backend Status Update Flow

### Cache-Based Job Lifecycle 

**1. Job Creation**
- Controller generates unique job_id using `SecureRandom.hex(8)`
- Controller stores initial status in cache: `Rails.cache.write("job_status:import:#{template_id}:#{job_id}", { status: :pending, created_at: Time.current }, expires_in: 24.hours)`
- Controller enqueues background job with template_id and job_id parameters
- Controller redirects user to status page: `/import_templates/#{template_id}/jobs/#{job_id}`

**2. Job Start**
- Job begins execution: `perform(template_id, job_id)` method called
- Job updates cache: `JobStatusService.update_status(job_id, :processing, started_at: Time.current)`
- JobStatusService broadcasts status change via Turbo Streams to channel `"job_status_#{job_id}"`

**3. Job Processing**
- Job calls existing service objects (import/export services) unchanged
- Services perform actual file processing work without knowing about job status
- Job catches any exceptions from service objects
- Job can optionally update progress: `JobStatusService.update_progress(job_id, "Processing row 100 of 500")`

**4. Job Completion (Success)**
- Job updates cache: `JobStatusService.update_status(job_id, :completed, completed_at: Time.current, result_data: service_result)`
- JobStatusService broadcasts completion via Turbo Streams
- Cache entry remains available for 24 hours then auto-expires

**5. Job Completion (Failure)**
- Job catches exception from service objects
- Job updates cache: `JobStatusService.update_status(job_id, :failed, completed_at: Time.current, error_message: exception.message)`
- JobStatusService broadcasts failure via Turbo Streams
- Cache entry remains available for 24 hours for debugging, then auto-expires

### Cache-Based Implementation Details

**JobStatusService**
```ruby
# app/services/job_status_service.rb
class JobStatusService < ApplicationService
  def self.cache_key(job_id)
    "job_status:#{job_id}"
  end
  
  def self.get_status(job_id)
    Rails.cache.read(cache_key(job_id)) || { status: :not_found }
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
  end
  
  def self.update_progress(job_id, progress_message)
    update_status(job_id, :processing, progress: progress_message)
  end
  
  private
  
  def self.broadcast_status_change(job_id, status_data)
    Turbo::StreamsChannel.broadcast_replace_to(
      "job_status_#{job_id}",
      target: "job_status_#{job_id}",
      partial: "shared/job_status",
      locals: { job_id: job_id, status_data: status_data }
    )
  end
end
```

**Background Job Implementation**
```ruby
# app/jobs/import_processing_job.rb
class ImportProcessingJob < ApplicationJob
  def perform(import_template_id, job_id, file_path)
    template = ImportTemplate.find(import_template_id)
    
    # Update to processing
    JobStatusService.update_status(job_id, :processing, 
      started_at: Time.current,
      template_name: template.name
    )
    
    # Call existing service unchanged
    uploaded_file = ActionDispatch::Http::UploadedFile.new(
      tempfile: File.open(file_path),
      filename: File.basename(file_path),
      type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
    )
    
    service_result = ExcelImportService.new(uploaded_file, template).process_import
    
    if service_result.success
      JobStatusService.update_status(job_id, :completed,
        completed_at: Time.current,
        result_summary: service_result.summary,
        processed_count: service_result.processed_count
      )
    else
      JobStatusService.update_status(job_id, :failed,
        completed_at: Time.current,
        error_message: service_result.errors.join('; ')
      )
    end
  rescue => e
    JobStatusService.update_status(job_id, :failed,
      completed_at: Time.current,
      error_message: e.message
    )
  ensure
    # Clean up temporary file
    File.delete(file_path) if File.exist?(file_path)
  end
end
```

## Non-Goals (Out of Scope)

- **Job Priorities**: No high/low priority queues - single default queue only
- **Detailed Progress Bars**: No percentage-based progress tracking - simple status and optional progress messages only
- **Job Scheduling**: No cron-like scheduled jobs - only on-demand processing
- **Email Notifications**: No email alerts - only in-app notifications
- **Job History Management**: No advanced filtering or search of job history
- **Bulk Operations**: No batch processing of multiple files simultaneously
- **Job Cancellation**: No ability to cancel running jobs
- **Queue Monitoring Dashboard**: No admin interface for queue management
- **Persistent Job Storage**: No database tables for job status - cache-only storage that auto-expires
- **Long-term Job History**: Job status only retained for 24 hours in cache

## Technical Considerations

### Cache-Based Architecture Benefits
- **No Database Schema Changes**: Existing models remain unchanged, no migrations required
- **Automatic Cleanup**: Job status automatically expires from cache after 24 hours
- **High Performance**: Cache reads/writes are much faster than database operations
- **Loose Coupling**: Services remain completely independent of job status tracking
- **Scalability**: Cache-based approach scales better than database status tracking

### Solid Queue Integration
- Leverage existing Rails 8 Solid Queue configuration
- Create job classes following Rails conventions: `ImportProcessingJob`, `ExportGenerationJob`
- Jobs must be idempotent and handle retries safely
- Use proper error handling and logging within job classes
- Jobs receive `job_id` parameter for cache-based status updates

### Service Object Integration
- Jobs wrap existing import/export services without any service modifications
- Services maintain current validation and business logic completely unchanged
- Jobs handle all status updates via JobStatusService, services remain status-agnostic
- Services return result objects that jobs inspect for success/failure status
- Zero impact on existing service object interfaces or functionality

### File Handling
- Uploaded files stored temporarily in filesystem during job processing
- Controller saves uploaded file to temp location before job enqueueing
- Job receives file path parameter and creates ActionDispatch::Http::UploadedFile for service compatibility
- Temporary files cleaned up automatically in job's ensure block

### Dependencies
- No new gems required - Solid Queue and Solid Cache are already configured in Rails 8
- Integration with existing authentication and authorization systems  
- Compatibility with current Turbo/Stimulus frontend architecture
- JobStatusService uses Rails.cache (Solid Cache) for all status operations

## Success Metrics

1. **User Experience**: Zero UI blocking during file uploads
2. **Reliability**: 99% job completion rate for valid files
3. **Performance**: Support for files 10x larger than current sync processing limits
4. **Error Handling**: 100% of failed jobs provide clear error messages to users
5. **Real-time Updates**: Job status updates appear within 2 seconds of status changes

## Open Questions

1. **Cache Key Strategy**: Should we include user_id in cache keys for additional security/isolation, or rely on job_id uniqueness?
2. **Retry Logic**: Should failed jobs automatically retry, or require user intervention?
3. **File Storage Location**: Should temporary files be stored in `/tmp` or a dedicated uploads temp directory?
4. **Job Status Expiration**: Is 24 hours the right cache expiration time, or should it be configurable?
5. **Progress Granularity**: How detailed should optional progress messages be (row counts, validation steps, etc.)?
6. **Multi-job Support**: Should one import template be able to have multiple concurrent jobs, or should new jobs cancel/replace pending ones?