# PRD: Dynamic Column System

## Introduction/Overview

The current XLS Importer application has a hardcoded limitation of 5 columns per import template. This constraint reduces flexibility for users who need to import Excel files with varying numbers of columns. This feature will implement a dynamic column system that allows import templates to support unlimited columns, configured through an intuitive add/remove interface.

**Problem:** Users are limited to exactly 5 columns per import template, regardless of their actual data needs.

**Goal:** Enable flexible column configuration for import templates to accommodate any number of columns based on user requirements.

## Goals

1. **Remove column limitations**: Allow import templates to support unlimited columns (no hardcoded 5-column restriction)
2. **Improve user flexibility**: Enable template creators to configure exactly the columns they need
3. **Maintain data integrity**: Ensure robust validation and type safety for dynamic column structures  
4. **Preserve Excel integration**: Maintain seamless import/export functionality with dynamic column structures
5. **Ensure performance**: Implement efficient database queries despite increased schema complexity

## User Stories

1. **As a template creator**, I want to add/remove columns individually when creating import templates so that I can match my Excel file structure exactly.

2. **As a template creator**, I want to configure each column's name and data type independently so that my data is properly validated and formatted.

3. **As a data importer**, I want to upload Excel files with varying numbers of columns so that I'm not constrained by artificial limits.

4. **As a data viewer**, I want to see all my imported data properly organized regardless of how many columns it contains.

5. **As a template creator**, I want to export sample Excel files that include all my configured columns so that data entry is streamlined.

## Functional Requirements

1. **Template Column Management**
   1.1. The system must allow adding new columns to import templates via "Add Column" button
   1.2. The system must allow removing existing columns via individual "Remove" buttons  
   1.3. The system must support reordering columns within a template
   1.4. Each column must be configurable with: name, data type (string/number/date/boolean), and required status

2. **Database Schema Changes**
   2.1. The system must implement a `template_columns` table to store column definitions
   2.2. The system must implement a `data_record_values` table to store individual cell values
   2.3. The system must maintain referential integrity between templates, columns, and values
   2.4. The system must support efficient querying despite the normalized structure

3. **Excel Import Processing**
   3.1. The system must validate uploaded Excel headers against dynamic template column definitions
   3.2. The system must process Excel data for any number of columns defined in the template
   3.3. The system must provide clear error messages when column mismatches occur
   3.4. The system must maintain existing data validation logic for each column type

4. **Excel Export Generation**
   4.1. The system must generate Excel files with all configured columns as headers
   4.2. The system must export all data values in their appropriate columns
   4.3. The system must maintain proper Excel formatting for different data types

5. **User Interface Updates**
   5.1. Template creation/editing pages must display dynamic column configuration interface
   5.2. Data viewing pages must render tables with dynamic column structures
   5.3. Import forms must show expected headers based on actual template configuration
   5.4. The system must provide intuitive visual feedback during column management

## Non-Goals (Out of Scope)

1. **Migration of existing data**: Legacy templates with 5 columns do not need to be migrated
2. **Column-level permissions**: All template creators have the same column management capabilities  
3. **Advanced column types**: Complex data types beyond string/number/date/boolean
4. **Column formulas**: Calculated or derived column values
5. **Column relationships**: Foreign key relationships between columns in different templates

## Technical Considerations

**Database Schema Changes:**
- New `template_columns` table: `id, import_template_id, column_number, name, data_type, required`
- New `data_record_values` table: `id, data_record_id, template_column_id, value`
- Modified `data_records` table: Remove `column_1` through `column_5`, keep metadata fields

**Performance Considerations:**
- Implement database indexes on `template_column_id` and `data_record_id` for efficient joins
- Consider query optimization for templates with many columns
- Add pagination for data viewing with large column counts

**Integration Points:**
- Update Excel import service to work with dynamic column mappings
- Modify Excel export service to generate dynamic column headers
- Update validation services to work with flexible column structures

## Design Considerations

**Template Configuration Interface:**
- Column management section with add/remove controls
- Drag-and-drop reordering of columns
- Inline editing of column properties (name, type, required)
- Visual preview of resulting Excel structure

**Data Viewing Interface:**
- Responsive table design for varying column widths
- Horizontal scrolling for templates with many columns
- Column header tooltips showing data types
- Consistent styling regardless of column count

## Success Metrics

1. **Template flexibility**: Users can create templates with any number of columns (measured by template column count distribution)
2. **User adoption**: 80% of new templates created use non-standard column counts (not exactly 5)
3. **System performance**: Page load times remain under 2 seconds for templates with up to 50 columns
4. **Error reduction**: Decrease in import failures due to column mismatch errors by 90%
5. **User satisfaction**: Positive feedback on increased template flexibility

## Open Questions

1. Should there be a soft limit on column count for UI/performance reasons? (Recommend 100 columns)
2. How should column reordering affect existing data records?
3. Should column deletion cascade to remove associated data values?
4. What happens when a template column is deleted but Excel import expects that column?
5. Should we provide bulk column creation (e.g., "create 10 columns at once")?

## Implementation Priority

**Phase 1 (Core Functionality):**
- Database schema changes and migrations
- Basic add/remove column functionality  
- Excel import/export compatibility

**Phase 2 (Enhanced UX):**
- Column reordering and bulk operations
- Advanced validation and error handling
- Performance optimizations

**Phase 3 (Polish):**
- UI/UX improvements and responsive design
- Advanced column management features
- Comprehensive testing and documentation