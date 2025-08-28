# Controllers & Views PRD

## Problem Statement
Users need a web interface to:
1. Create and manage ImportTemplates with dynamic column definitions
2. View and manage DataRecords associated with templates
3. Navigate between different sections of the application
4. Prepare for Excel import/export functionality

## Requirements

### ImportTemplatesController
**Actions**:
- `index` - List all templates with name, description, created date
- `show` - Display template details and associated data records count
- `new` - Form to create new template
- `create` - Handle template creation
- `edit` - Form to modify existing template
- `update` - Handle template updates
- `destroy` - Delete template (with confirmation)

**Key Features**:
- Dynamic column configuration form (5 columns max)
- Each column needs: name and data_type (string, number, date, boolean)
- Validation feedback for form errors
- Template preview showing configured columns

### DataRecordsController
**Actions**:
- `index` - List all records for a specific template (nested route)
- `show` - Display individual record details
- `new` - Form to create new record for template
- `create` - Handle record creation
- `edit` - Form to modify existing record
- `update` - Handle record updates
- `destroy` - Delete record

**Key Features**:
- Dynamic form based on template's column definitions
- Data grid view with template-defined headers
- Filter/search capabilities
- Pagination for large datasets

### Views Structure

**ImportTemplates Views**:
```
app/views/import_templates/
├── index.html.erb          # Templates listing
├── show.html.erb           # Template details + records preview
├── new.html.erb            # New template form
├── edit.html.erb           # Edit template form
├── _form.html.erb          # Shared form partial
└── _template.html.erb      # Template card partial
```

**DataRecords Views**:
```
app/views/data_records/
├── index.html.erb          # Records listing for template
├── show.html.erb           # Record details
├── new.html.erb            # New record form
├── edit.html.erb           # Edit record form
├── _form.html.erb          # Dynamic form partial
└── _record.html.erb        # Record row partial
```

### Routes Structure
```ruby
Rails.application.routes.draw do
  root 'import_templates#index'
  
  resources :import_templates do
    resources :data_records, except: [:index]
    member do
      get :data_records, to: 'data_records#index'
    end
  end
end
```

### UI/UX Requirements
- **Framework**: TailwindCSS for styling
- **Responsiveness**: Mobile-friendly design
- **Navigation**: Header with main sections
- **Forms**: Clear labels, validation feedback
- **Tables**: Sortable columns, pagination
- **Actions**: Confirm dialogs for destructive actions

### Dynamic Column Form
The template creation form needs:
- 5 column configuration sections
- Each section has:
  - Column name input (text)
  - Data type select (string, number, date, boolean)
  - Option to enable/disable column
- Real-time preview of headers
- Client-side validation (basic)

### Data Grid Features
- Headers based on template column definitions
- Editable cells (future enhancement)
- Add/Edit/Delete actions per row
- Empty state when no records
- Loading states

## Acceptance Criteria
- [ ] Users can create templates with up to 5 dynamic columns
- [ ] Users can view list of all templates
- [ ] Users can add data records to templates
- [ ] Users can edit both templates and records
- [ ] Interface is responsive and uses TailwindCSS
- [ ] Navigation works between all sections
- [ ] Form validation provides clear feedback
- [ ] Destructive actions require confirmation

## Technical Notes
- Use Rails form helpers with proper CSRF protection
- Implement strong parameters for security
- Add flash messages for user feedback
- Use partials to reduce code duplication
- Prepare views for future Turbo/Stimulus enhancements