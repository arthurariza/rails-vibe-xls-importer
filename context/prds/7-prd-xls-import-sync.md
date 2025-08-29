# 7-PRD: XLS Import Source of Truth Synchronization

## Introduction/Overview

Currently, the Excel import feature adds new rows to existing data in the database. This PRD defines a change to make the uploaded XLS file the "source of truth" - meaning the imported file will completely replace all existing data for that template, ensuring the database matches exactly what's in the Excel file.

The goal is to transform the import process from an "additive" operation to a "synchronization" operation, where the XLS file defines the complete dataset for the template.

## Goals

1. **Data Synchronization**: Make uploaded XLS files the authoritative source of data for each template
2. **Data Integrity**: Ensure safe replacement of existing data using database transactions
3. **Precise Matching**: Use hidden ID columns in exports to enable exact record matching
4. **Validation First**: Validate entire file before making any database changes
5. **User Confidence**: Provide clear feedback that data will be replaced, not added

## User Stories

1. **As a data manager**, I want to export template data, edit it in Excel, and re-import to have my Excel changes reflected exactly in the database, so that I can use Excel as my primary data editing tool.

2. **As a template administrator**, I want to know that importing an XLS file will replace all existing data, so that I can confidently sync my external spreadsheet with the application.

3. **As a user**, I want the import to fail completely if there are any validation errors, so that I don't end up with partial or corrupted data.

4. **As a user**, I want to see clear feedback about what will happen during import (replace vs add), so that I understand the consequences of my action.

## Functional Requirements

1. **Export Enhancement**: Excel exports must include a hidden ID column to enable precise record matching during import.

2. **Import Validation**: The system must validate the entire Excel file (headers, data types, required fields) before making any database changes.

3. **Transaction Safety**: All data replacement must occur within a single database transaction to prevent data loss if import fails.

4. **Record Matching**: The system must match imported rows to existing database records using the hidden ID column from exports.

5. **Complete Replacement**: For each successful import:
   - Update existing records that have matching IDs in the import file
   - Create new records for rows without IDs or with non-existent IDs  
   - Delete existing records whose IDs are not present in the import file

6. **Failure Handling**: If validation fails at any point, the system must reject the entire import and preserve all existing data unchanged.

7. **User Feedback**: The import form must clearly indicate that importing will "replace all data" rather than "add new data".

8. **Batch Processing**: The entire import file must be processed in one transaction (not batched into smaller chunks).

## Non-Goals (Out of Scope)

- Import history or audit trail functionality
- Data backup before import
- User preview/confirmation of changes before import
- Partial import capabilities (all-or-nothing approach)
- Size limits beyond current file upload restrictions

## Technical Considerations

### Export Service Changes
- Add hidden "id" column as first column in all Excel exports
- Include existing record IDs for data exports
- Generate placeholder IDs or leave blank for template-only exports

### Import Service Changes  
- Parse hidden ID column to identify existing vs new records
- Implement three-phase import process:
  1. **Validation Phase**: Validate all data without database changes
  2. **Matching Phase**: Identify records to update, create, and delete
  3. **Transaction Phase**: Execute all changes within single transaction

### Database Transaction Strategy
```ruby
ActiveRecord::Base.transaction do
  # Delete records not in import file
  # Update existing records with new data
  # Create new records from import file
end
```

### Validation Requirements
- Header validation (existing functionality)
- Data type validation for all rows
- Required field validation
- ID column presence validation

## Success Metrics

1. **Data Consistency**: 100% accuracy between imported Excel data and database state after import
2. **Transaction Safety**: Zero instances of partial data loss during failed imports  
3. **User Experience**: Clear understanding that import replaces (not adds) data
4. **Performance**: Import processing time remains acceptable for typical file sizes

## Open Questions

1. Should we add a confirmation dialog showing "This will replace X existing records" before proceeding?
2. How should we handle records with duplicate IDs within the same import file?
3. Should the hidden ID column be configurable or always use the standard Rails ID?
4. Do we need to handle imports of files that were exported from different template versions?