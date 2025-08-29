# Tasks: XLS Import Source of Truth Synchronization

## Relevant Files

- `app/services/excel_export_service.rb` - Export service that needs hidden ID column functionality
- `app/services/excel_import_service.rb` - Import service that needs synchronization behavior instead of additive behavior
- `app/services/header_validation_service.rb` - May need updates to handle ID column validation
- `app/views/import_templates/import_form.html.erb` - UI text updates to indicate data replacement
- `app/controllers/import_templates_controller.rb` - Controller that handles import actions
- `test/services/excel_export_service_test.rb` - Tests for export service changes
- `test/services/excel_import_service_test.rb` - Tests for import service synchronization behavior
- `test/controllers/import_templates_controller_test.rb` - Integration tests for import flow

### Notes

- Tests should verify the new synchronization behavior (update/create/delete operations)
- Use `bin/rails test` to run all tests
- Use `bin/rubocop` for code style validation

## Tasks

- [x] 1.0 Modify Excel Export Service to include hidden ID column
  - [x] 1.1 Add ID column as first column in `add_headers` method
  - [x] 1.2 Update `build_row_data` method to include record ID as first column value
  - [x] 1.3 Update `build_sample_row_data` method to include placeholder ID values
  - [x] 1.4 Ensure ID column header is not visible to users (use hidden/internal name)
  - [x] 1.5 Update header styling to accommodate ID column
  
- [x] 2.0 Update Excel Import Service for synchronization behavior
  - [x] 2.1 Modify `extract_headers` method to detect and handle ID column
  - [x] 2.2 Update HeaderValidationService to ignore/validate ID column appropriately  
  - [x] 2.3 Modify `process_data_rows` to parse ID values and build sync plan
  - [x] 2.4 Replace `process_single_row` with `sync_records` method that handles update/create/delete
  - [x] 2.5 Implement transaction-based synchronization logic
  - [x] 2.6 Update ImportResult class to track sync operations (updated, created, deleted counts)
  - [x] 2.7 Add validation phase that processes entire file before any database changes
  
- [ ] 3.0 Update Import UI to indicate data replacement behavior  
  - [x] 3.1 Update import form text to clearly state "replace all data" instead of "add data"
  - [x] 3.2 Update import instructions to explain synchronization behavior
  - [x] 3.3 Update import success/error messages to reflect sync operations
  
- [ ] 4.0 Update tests for new synchronization functionality
  - [ ] 4.1 Update ExcelExportService tests to verify ID column inclusion
  - [ ] 4.2 Create ExcelImportService tests for synchronization scenarios (update existing, create new, delete missing)
  - [ ] 4.3 Add test fixtures with ID columns for import testing
  - [ ] 4.4 Update controller integration tests for new sync behavior
  - [ ] 4.5 Test transaction rollback scenarios (validation failures)
  - [ ] 4.6 Test edge cases (duplicate IDs, invalid IDs, missing ID column)