# 6-PRD: JavaScript to Hotwire Conversion

## Problem Statement
The import form currently uses custom JavaScript for file upload functionality, which violates the project requirement to use "HTML + ERB and hotwire" for frontend without manual JavaScript. The custom JavaScript handles file selection feedback, drag-and-drop functionality, and visual state changes.

## Requirements

### Functional Requirements
1. **File Selection Feedback**: Display selected file name and size when user selects a file
2. **Drag and Drop**: Support drag-and-drop file upload with visual feedback
3. **Visual State Changes**: Update upload area appearance based on interaction states
4. **Click to Upload**: Allow clicking the upload area to trigger file selection
5. **File Validation**: Show appropriate feedback for valid/invalid files

### Technical Requirements
1. **No Custom JavaScript**: Remove all `<script>` tags and inline JavaScript
2. **Stimulus Controllers**: Use Stimulus controllers for all interactions
3. **Hotwire Patterns**: Follow proper `data-controller`, `data-action`, and `data-target` conventions
4. **Progressive Enhancement**: Ensure functionality works without JavaScript
5. **Accessibility**: Maintain keyboard and screen reader accessibility

### Non-Functional Requirements
1. **Performance**: No degradation in file upload experience
2. **Browser Compatibility**: Support modern browsers (same as current)
3. **Responsive Design**: Maintain responsive behavior on all devices

## Current JavaScript Analysis

### Existing Functionality
- `updateFileName(input)` function handles file selection display
- Drag and drop event listeners (dragover, dragleave, drop)
- Click event listener for upload area
- CSS class manipulation for visual states
- File size calculation and formatting

### Dependencies
- DOM manipulation via `getElementById`, `classList`
- File API for reading selected files
- Event handling for drag/drop and click events

## Proposed Solution

### Stimulus Controller Architecture
Create a `file_upload_controller.js` that handles:
1. File selection events via Stimulus actions
2. Element targeting via Stimulus targets
3. State management via Stimulus values
4. Lifecycle callbacks for initialization

### Implementation Strategy
1. **Controller Creation**: Build Stimulus controller with proper actions and targets
2. **Template Updates**: Replace JavaScript with Stimulus data attributes
3. **Event Handling**: Convert all event listeners to Stimulus actions
4. **State Management**: Use Stimulus values for component state
5. **Progressive Enhancement**: Ensure form works without JavaScript

## Success Criteria
1. ✅ File upload works identically to current implementation
2. ✅ All custom JavaScript removed from ERB templates
3. ✅ Drag and drop functionality preserved
4. ✅ Visual feedback maintains current UX
5. ✅ Code follows Stimulus conventions and best practices
6. ✅ No console errors or JavaScript warnings

## Technical Risks
- **File API Compatibility**: Ensure File API works within Stimulus context
- **Event Handling**: Proper event delegation for drag/drop
- **State Synchronization**: Maintaining visual states across actions

## Timeline
- **Phase 1**: Create Stimulus controller (30 minutes)
- **Phase 2**: Update ERB template (15 minutes) 
- **Phase 3**: Remove JavaScript and test (15 minutes)
- **Total**: ~1 hour

## Dependencies
- Existing Stimulus setup in Rails application
- Current TailwindCSS classes for styling
- File upload form structure