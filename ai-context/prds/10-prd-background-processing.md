# 10 - Background Processing with Solid Queue

## Introduction/Overview

This feature introduces asynchronous background processing for time-intensive operations in the XLS Importer application. Currently, file imports and exports are processed synchronously, causing UI blocking, potential timeouts with large files, and poor user experience. By implementing Solid Queue (already included in Rails 8), we will move these operations to background jobs, allowing users to continue working while their files are processed.

The feature addresses all current pain points: UI blocking during processing, timeout issues with large files, and the requirement for users to remain on pages during lengthy operations.

## Goals

1. **Improve User Experience**: Enable non-blocking file imports and exports so users can continue working while processing occurs
2. **Handle Larger Files**: Support processing of larger XLS files without HTTP timeout constraints
3. **Provide Real-time Feedback**: Show live job status updates using Turbo Streams without page refreshes
4. **Ensure Reliability**: Implement proper error handling with user notifications when jobs fail

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
5. The system must update job status in real-time using Turbo Streams

### Backend Job Status Updates
6. **Job Initialization**: When a background job starts, it must update the model status from `:pending` to `:processing` and set `processing_started_at` timestamp
7. **Progress Tracking**: The job must update the model status at key processing milestones (e.g., after file parsing, after validation, after data processing)
8. **Success Completion**: When a job completes successfully, it must update the model status to `:completed` and set `processing_completed_at` timestamp
9. **Failure Handling**: When a job fails, it must update the model status to `:failed`, set `processing_completed_at` timestamp, and store the error message in the `error_message` field
10. **Turbo Stream Broadcasting**: After each status update, the job must trigger a Turbo Stream broadcast to notify the frontend of the change

### User Interface
11. The system must redirect users to a job status page immediately after file upload
12. The system must display job status as simple pending/completed/failed states
13. The system must show real-time updates without requiring page refreshes
14. The system must provide clear error messages when jobs fail
15. The system must allow users to navigate away from job status pages and return later

### Model Integration
16. The system must add status enum to existing import/export models: `:pending, :processing, :completed, :failed`
17. The system must add timestamp fields: `processing_started_at`, `processing_completed_at`
18. The system must add `error_message` text field for storing failure details
19. The system must add `background_job_id` field to track the actual Solid Queue job
20. The system must include after_update callbacks to broadcast Turbo Stream updates when status changes

### Integration
21. The system must integrate with existing import/export services
22. The system must maintain existing file validation and processing logic
23. The system must work seamlessly with the current authentication system
24. The system must follow Rails job conventions from the project's rails-rules.md

## Backend Status Update Flow

### Job Lifecycle and Model Updates

**1. Job Creation**
- Controller creates model record with `status: :pending`
- Controller enqueues background job with model ID
- Model stores `background_job_id` for tracking
- Controller redirects user to status page

**2. Job Start**
- Job begins execution: `perform` method called
- Job updates model: `status: :processing, processing_started_at: Time.current`
- Model after_update callback broadcasts status change via Turbo Streams

**3. Job Processing**
- Job calls existing service objects (import/export services)
- Services perform actual file processing work
- Job catches any exceptions from service objects

**4. Job Completion (Success)**
- Job updates model: `status: :completed, processing_completed_at: Time.current`
- Model after_update callback broadcasts completion via Turbo Streams
- Job clears `background_job_id` field

**5. Job Completion (Failure)**
- Job catches exception from service objects
- Job updates model: `status: :failed, processing_completed_at: Time.current, error_message: exception.message`
- Model after_update callback broadcasts failure via Turbo Streams
- Job clears `background_job_id` field

### Status Update Implementation Details

**Model Callbacks**
```ruby
# In ImportTemplate or relevant model
after_update :broadcast_status_change, if: :saved_change_to_status?

private

def broadcast_status_change
  broadcast_replace_to "job_#{id}", 
    partial: "shared/job_status", 
    locals: { job: self }
end
```

**Job Status Updates**
```ruby
# In ImportProcessingJob
def perform(import_template_id)
  @import_template = ImportTemplate.find(import_template_id)
  
  # Update to processing
  @import_template.update!(
    status: :processing, 
    processing_started_at: Time.current
  )
  
  # Call existing service
  service_result = ImportService.new(template: @import_template).call
  
  if service_result.success?
    @import_template.update!(
      status: :completed,
      processing_completed_at: Time.current
    )
  else
    @import_template.update!(
      status: :failed,
      processing_completed_at: Time.current,
      error_message: service_result.error_message
    )
  end
rescue => e
  @import_template.update!(
    status: :failed,
    processing_completed_at: Time.current,
    error_message: e.message
  )
end
```

## Non-Goals (Out of Scope)

- **Job Priorities**: No high/low priority queues - single default queue only
- **Detailed Progress Bars**: No percentage-based progress tracking - simple status only
- **Job Scheduling**: No cron-like scheduled jobs - only on-demand processing
- **Email Notifications**: No email alerts - only in-app notifications
- **Job History Management**: No advanced filtering or search of job history
- **Bulk Operations**: No batch processing of multiple files simultaneously
- **Job Cancellation**: No ability to cancel running jobs
- **Queue Monitoring Dashboard**: No admin interface for queue management
- **Separate Jobs Table**: No additional database table - use existing model enums

## Technical Considerations

### Solid Queue Integration
- Leverage existing Rails 8 Solid Queue configuration
- Create job classes following Rails conventions: `ImportProcessingJob`, `ExportGenerationJob`
- Jobs must be idempotent and handle retries safely
- Use proper error handling and logging within job classes

### Service Object Integration
- Jobs wrap existing import/export services
- Services maintain current validation and business logic
- Jobs handle status updates, services focus on business logic
- Services return result objects that jobs can inspect for success/failure

### Dependencies
- No new gems required - Solid Queue is already configured in Rails 8
- Integration with existing authentication and authorization systems  
- Compatibility with current Turbo/Stimulus frontend architecture

## Success Metrics

1. **User Experience**: Zero UI blocking during file uploads
2. **Reliability**: 99% job completion rate for valid files
3. **Performance**: Support for files 10x larger than current sync processing limits
4. **Error Handling**: 100% of failed jobs provide clear error messages to users
5. **Real-time Updates**: Job status updates appear within 2 seconds of status changes

## Open Questions

1. **Model Selection**: Which existing models should have status enums added (ImportTemplate, Export, etc.)?
2. **Retry Logic**: Should failed jobs automatically retry, or require user intervention?
3. **File Storage**: Where should uploaded files be temporarily stored while jobs are queued?
4. **Service Integration**: Should existing services be modified to accept status update callbacks, or should jobs handle all status management?
5. **Job Cleanup**: Should we clean up the `background_job_id` field immediately after completion or keep it for debugging?