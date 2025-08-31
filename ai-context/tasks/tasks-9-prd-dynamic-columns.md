# Tasks: Dynamic Column System

## Relevant Files

- `db/migrate/create_template_columns.rb` - Migration to create template_columns table for dynamic column definitions
- `db/migrate/create_data_record_values.rb` - Migration to create data_record_values table for normalized data storage
- `db/migrate/migrate_existing_data.rb` - Migration to move existing column data to new structure
- `app/models/template_column.rb` - Model for individual template column definitions
- `app/models/data_record_value.rb` - Model for individual data cell values
- `app/models/import_template.rb` - Updated to work with dynamic columns via associations
- `app/models/data_record.rb` - Updated to work with normalized data storage
- `app/controllers/template_columns_controller.rb` - CRUD operations for managing template columns
- `app/views/import_templates/_column_fields.html.erb` - Dynamic column configuration interface
- `app/views/import_templates/_form.html.erb` - Updated template form with dynamic column management
- `app/views/import_templates/show.html.erb` - Updated to display dynamic column information
- `app/views/data_records/index.html.erb` - Dynamic table rendering for variable column counts
- `app/services/excel_import_service.rb` - Updated to handle dynamic column mappings
- `app/services/excel_export_service.rb` - Updated to generate dynamic Excel structures
- `app/services/header_validation_service.rb` - Updated to validate against dynamic template columns
- `app/javascript/controllers/column_manager_controller.js` - Stimulus controller for add/remove column functionality
- `test/models/template_column_test.rb` - Unit tests for TemplateColumn model
- `test/models/data_record_value_test.rb` - Unit tests for DataRecordValue model
- `test/controllers/template_columns_controller_test.rb` - Controller tests for column management
- `test/services/excel_import_service_test.rb` - Updated tests for dynamic import functionality
- `test/services/excel_export_service_test.rb` - Updated tests for dynamic export functionality

### Notes

- This is a major architectural change that affects the core data model
- Existing tests will need updates to work with the new normalized structure
- Consider database performance implications with the new join-heavy queries

## Tasks

- [x] 1.0 Create Database Schema for Dynamic Columns
  - [x] 1.1 Create migration for `template_columns` table with fields: id, import_template_id, column_number, name, data_type, required, created_at, updated_at
  - [x] 1.2 Create migration for `data_record_values` table with fields: id, data_record_id, template_column_id, value, created_at, updated_at
  - [x] 1.3 Add database indexes for performance: template_column_id, data_record_id, import_template_id on template_columns
  - [x] 1.4 Add foreign key constraints for referential integrity
  - [x] 1.5 Create data migration to move existing column_1-column_5 data to new normalized structure
  - [x] 1.6 Run migrations and verify schema changes

- [x] 2.0 Create New Model Classes and Associations
  - [x] 2.1 Create `TemplateColumn` model with validations for name, data_type, column_number
  - [x] 2.2 Create `DataRecordValue` model with belongs_to associations to data_record and template_column
  - [x] 2.3 Add validation in TemplateColumn for data_type enum (string, number, date, boolean)
  - [x] 2.4 Add scopes in TemplateColumn for ordered columns (by column_number)
  - [x] 2.5 Add callbacks for maintaining column_number sequence when columns are added/removed

- [x] 3.0 Update Import Template Model for Dynamic Columns
  - [x] 3.1 Add `has_many :template_columns` association with dependent: :destroy, ordered by column_number
  - [x] 3.2 Replace hardcoded `column_headers` method to use template_columns association
  - [x] 3.3 Replace `column_definition` method to query template_columns instead of JSON
  - [x] 3.4 Remove `column_definitions` JSON field and related validations
  - [x] 3.5 Add helper methods: `add_column(name, data_type)`, `remove_column(column_number)`, `reorder_columns`
  - [x] 3.6 Add validation to ensure at least one column exists per template

- [x] 4.0 Update Data Record Model for Normalized Storage
  - [x] 4.1 Add `has_many :data_record_values` association with dependent: :destroy
  - [x] 4.2 Remove direct column_1-column_5 methods and replace with dynamic value access
  - [x] 4.3 Create `value_for_column(template_column)` method to retrieve values by column
  - [x] 4.4 Create `set_value_for_column(template_column, value)` method to set values
  - [x] 4.5 Update `column_values` method to work with dynamic columns via template_columns
  - [x] 4.6 Update `data_hash` method to use template_columns for key generation
  - [x] 4.7 Add validation to ensure values exist for required columns

- [x] 5.0 Create Template Column Management Controller
  - [x] 5.1 Create `TemplateColumnsController` with create, update, destroy actions
  - [x] 5.2 Add nested routes under import_templates for template column management
  - [x] 5.3 Implement `create` action to add new columns to templates with proper column_number sequencing
  - [x] 5.4 Implement `update` action to modify column properties (name, data_type, required)
  - [x] 5.5 Implement `destroy` action to remove columns and handle data cleanup
  - [x] 5.6 Add authorization to ensure users can only modify their own template columns
  - [x] 5.7 Add JSON responses for AJAX column management operations

- [x] 6.0 Build Dynamic Column Configuration UI
  - [x] 6.1 Create `_column_fields.html.erb` partial for rendering individual column configuration forms
  - [x] 6.2 Update `import_templates/_form.html.erb` to include dynamic column management section
  - [x] 6.3 Add "Add Column" button that dynamically adds new column configuration fields
  - [x] 6.4 Add "Remove" buttons for each column with confirmation prompts
  - [x] 6.5 Include drag-and-drop handles for column reordering (using Sortable.js or similar)
  - [x] 6.6 Add inline validation feedback for column names and data types
  - [x] 6.7 Show preview of resulting Excel structure based on configured columns

- [x] 7.0 Update Excel Import Service for Dynamic Processing
  - [x] 7.1 Modify `extract_headers` method to work with any number of columns
  - [x] 7.2 Update header validation to check against template_columns instead of hardcoded column_definitions
  - [x] 7.3 Modify `build_record_attributes_raw` to create DataRecordValue objects instead of column_1-5 attributes
  - [x] 7.4 Update `process_single_row` to iterate through template_columns and create corresponding values
  - [x] 7.5 Modify error reporting to reference dynamic column names in error messages
  - [x] 7.6 Update batch processing to handle variable column counts efficiently

- [x] 8.0 Update Excel Export Service for Dynamic Generation
  - [x] 8.1 Replace hardcoded column headers with dynamic template_columns query
  - [x] 8.2 Update header row generation to output all configured column names
  - [x] 8.3 Modify data row generation to iterate through template_columns and extract values
  - [x] 8.4 Ensure proper Excel formatting for dynamic column types (string, number, date, boolean)
  - [x] 8.5 Add column width auto-sizing based on content and column names
  - [x] 8.6 Test export functionality with templates having different column counts

- [ ] 9.0 Update Header Validation for Dynamic Templates
  - [ ] 9.1 Modify `HeaderValidationService` to query template_columns instead of column_definitions
  - [ ] 9.2 Update validation logic to handle variable numbers of expected headers
  - [ ] 9.3 Improve error messages to show actual template column names from database
  - [ ] 9.4 Update `create_header_mapping` to work with template_column IDs instead of hardcoded numbers
  - [ ] 9.5 Add validation for column order matching between Excel and template configuration

- [ ] 10.0 Create Frontend Column Management Interface
  - [ ] 10.1 Create `column_manager_controller.js` Stimulus controller for dynamic column interactions
  - [ ] 10.2 Implement `addColumn` action to dynamically add new column configuration fields
  - [ ] 10.3 Implement `removeColumn` action with confirmation and proper form field removal
  - [ ] 10.4 Add drag-and-drop functionality for column reordering with visual feedback
  - [ ] 10.5 Implement real-time Excel structure preview updates as columns change
  - [ ] 10.6 Add client-side validation for column names (uniqueness, required fields)
  - [ ] 10.7 Handle AJAX form submissions for seamless column management without page reloads

- [ ] 11.0 Update Data Viewing Interface for Dynamic Columns
  - [ ] 11.1 Modify `data_records/index.html.erb` to render dynamic table headers from template_columns
  - [ ] 11.2 Update table body to display values from data_record_values association
  - [ ] 11.3 Add responsive design for tables with many columns (horizontal scrolling)
  - [ ] 11.4 Implement column header tooltips showing data types and requirements
  - [ ] 11.5 Add pagination handling for large datasets with many columns
  - [ ] 11.6 Update `show.html.erb` for individual data records to display all dynamic columns
  - [ ] 11.7 Add export functionality from data viewing pages

- [ ] 12.0 Update Tests for New Architecture
  - [ ] 12.1 Create comprehensive unit tests for `TemplateColumn` model including validations and associations
  - [ ] 12.2 Create unit tests for `DataRecordValue` model with proper association testing
  - [ ] 12.3 Update `ImportTemplate` model tests to work with new dynamic column associations
  - [ ] 12.4 Update `DataRecord` model tests to use new value storage methods
  - [ ] 12.5 Create controller tests for `TemplateColumnsController` covering CRUD operations
  - [ ] 12.6 Update `ExcelImportService` tests to cover dynamic column processing scenarios
  - [ ] 12.7 Update `ExcelExportService` tests for dynamic column generation
  - [ ] 12.8 Create integration tests for end-to-end dynamic column workflows
  - [ ] 12.9 Add performance tests for templates with large numbers of columns (50+)
  - [ ] 12.10 Update system tests for column management UI interactions