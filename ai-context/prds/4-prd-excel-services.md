# Excel Import/Export Services PRD

## Problem Statement
Users need to export ImportTemplate data as Excel files and import Excel files back into the application. This is the core functionality that completes the round-trip workflow:
1. Create template with dynamic columns
2. Export Excel file with template headers
3. Fill data in Excel
4. Import Excel file back to create/update DataRecords

## Requirements

### Excel Export Functionality

**ExcelExportService Requirements:**
- Generate Excel files from ImportTemplate definitions
- Include only configured columns (skip empty column definitions)
- Create proper headers based on template column names
- Export existing DataRecords as data rows
- Support both template-only export (headers only) and data export
- Generate downloadable .xlsx files

**Export Types:**
1. **Template Export** - Headers only, ready for data entry
2. **Data Export** - Headers + all existing DataRecords
3. **Sample Export** - Headers + 3 sample rows with placeholder data

### Excel Import Functionality

**ExcelImportService Requirements:**
- Accept uploaded .xlsx/.xls files
- Validate file format and readability
- Perform header validation against template
- Process rows and create/update DataRecords
- Handle data type conversion and validation
- Provide detailed error reporting
- Support batch processing with import_batch_id

**HeaderValidationService Requirements:**
- Compare uploaded Excel headers with template column names
- Allow flexible matching (case-insensitive, whitespace handling)
- Report missing required columns
- Report extra columns in uploaded file
- Suggest header mappings when possible

### User Interface Requirements

**Export UI:**
- Export buttons on ImportTemplate show page
- Export options: Template Only, With Data, With Sample Data
- Direct download without page reload
- Success/error feedback

**Import UI:**
- File upload form with drag-and-drop support
- File format validation (client-side and server-side)
- Upload progress indicator
- Header validation results display
- Import preview before processing
- Bulk import confirmation
- Error reporting with line numbers

## Technical Implementation

### Routes
```ruby
resources :import_templates do
  member do
    get :export_template    # Headers only
    get :export_data        # Headers + data
    get :export_sample      # Headers + sample
    get :import_form        # Upload form
    post :import_file       # Process upload
    get :import_preview     # Preview before import
    post :import_confirm    # Confirm import
  end
end
```

### Service Architecture
```
ExcelExportService
├── generate_template_file(template)
├── generate_data_file(template) 
└── generate_sample_file(template)

ExcelImportService
├── process_upload(file, template)
├── validate_file_format(file)
├── extract_data(file)
└── create_records(data, template)

HeaderValidationService  
├── validate_headers(excel_headers, template)
├── suggest_mappings(excel_headers, template)
└── report_issues(excel_headers, template)
```

### Data Processing Rules
- **String columns**: Accept any text, strip whitespace
- **Number columns**: Parse numbers, handle decimals, reject non-numeric
- **Date columns**: Parse common date formats, reject invalid dates  
- **Boolean columns**: Accept true/false, yes/no, 1/0, case-insensitive
- **Empty cells**: Allow empty for all types, respect model validations

### Error Handling
- File format errors: Clear message, suggest correct format
- Header mismatch: Show mapping suggestions
- Data validation errors: Line-by-line error reporting
- File size limits: Reasonable limits for prototype
- Duplicate handling: Skip or update existing records

## User Workflow

### Export Workflow
1. User views ImportTemplate details
2. Clicks "Export Template" or "Export Data"
3. File downloads immediately
4. User opens in Excel, adds/modifies data
5. Saves file for import

### Import Workflow  
1. User clicks "Import Data" on template page
2. Uploads Excel file via drag-drop or file picker
3. System validates headers and shows preview
4. User reviews preview and confirms import
5. System processes rows and creates DataRecords
6. Shows import summary with success/error counts

## Acceptance Criteria
- [ ] Users can export template headers as Excel file
- [ ] Users can export existing data as Excel file  
- [ ] Users can upload Excel files for import
- [ ] Header validation prevents mismatched imports
- [ ] Row processing creates valid DataRecords
- [ ] Import errors are clearly reported with line numbers
- [ ] File operations work without page reloads (Turbo)
- [ ] Large files are handled gracefully
- [ ] Import creates proper import_batch_id for grouping

## Technical Notes
- Use `caxlsx` for Excel generation (already installed)
- Use `roo` for Excel reading (already installed)
- Implement proper streaming for large files
- Use Rails file upload best practices
- Add proper MIME type validation
- Consider memory usage for large imports
- Use background jobs for large imports (future enhancement)