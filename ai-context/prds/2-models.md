# Models and Database Schema PRD

## Problem Statement
The XLS Importer application needs to store two types of data:
1. **Template definitions** - What columns/headers the Excel files should have
2. **Actual data records** - The data imported from Excel files

## Requirements

### ImportTemplate Model
**Purpose**: Defines the structure and metadata for Excel files

**Fields**:
- `name` (string, required) - Human-readable template name
- `description` (text, optional) - Template description
- `column_definitions` (json) - Stores the 5 dynamic column configurations
- `created_at/updated_at` (timestamps)

**Column Definitions Structure**:
```json
{
  "column_1": {"name": "Employee ID", "data_type": "string"},
  "column_2": {"name": "Full Name", "data_type": "string"},
  "column_3": {"name": "Department", "data_type": "string"},
  "column_4": {"name": "Salary", "data_type": "number"},
  "column_5": {"name": "Start Date", "data_type": "date"}
}
```

**Validations**:
- Name must be present and unique
- Column definitions must contain exactly 5 columns
- Each column must have name and data_type

### DataRecord Model
**Purpose**: Stores the actual data imported from Excel files

**Fields**:
- `import_template_id` (foreign key) - Links to ImportTemplate
- `column_1` (text) - Data for first column
- `column_2` (text) - Data for second column  
- `column_3` (text) - Data for third column
- `column_4` (text) - Data for fourth column
- `column_5` (text) - Data for fifth column
- `import_batch_id` (string, optional) - Groups records from same import
- `created_at/updated_at` (timestamps)

**Relationships**:
- `belongs_to :import_template`
- ImportTemplate `has_many :data_records`

**Validations**:
- Must belong to an ImportTemplate
- At least one column must have data

## Data Type Considerations
- All columns stored as TEXT for flexibility
- Data type validation handled at application level
- Allows for easy import/export without type conversion issues

## Use Cases
1. **Create Template**: User defines 5 columns with names and types
2. **Export Excel**: Generate Excel file with headers from template
3. **Import Excel**: Validate headers match template, create DataRecords
4. **View Data**: Display records in grid format with proper column names

## Acceptance Criteria
- [ ] ImportTemplate can store 5 dynamic column definitions
- [ ] DataRecord can store data for all 5 columns
- [ ] Proper associations between models
- [ ] Validations prevent invalid data
- [ ] Models support Excel import/export workflow

## Migration Strategy
1. Create ImportTemplate table first
2. Create DataRecord table with foreign key
3. Add indexes for performance
4. Consider adding sample data via seeds