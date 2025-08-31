# Testing and Integration PRD

## Problem Statement
The XLS Importer prototype needs comprehensive testing to ensure the complete workflow functions correctly:
1. Template creation with dynamic columns
2. Excel export in multiple formats
3. Excel import with header validation
4. Data processing and error handling
5. Round-trip data integrity

## Testing Strategy

### Manual Testing Workflow
**Priority: High** - Since this is a prototype, manual testing of the complete user journey is essential.

**Test Scenarios:**
1. **Template Management**
   - Create template with 5 different column types
   - Edit template and modify column definitions
   - Delete template and verify cascading deletion

2. **Excel Export**
   - Export template-only file (headers only)
   - Export data file with existing records
   - Export sample file with placeholder data
   - Verify file downloads and Excel compatibility

3. **Excel Import**
   - Import valid Excel file with matching headers
   - Import file with mismatched headers (should fail gracefully)
   - Import file with various data types and formats
   - Import file with empty rows and invalid data
   - Verify batch processing and error reporting

4. **Data Integrity**
   - Complete round-trip: export → edit in Excel → import
   - Verify data types are preserved correctly
   - Check that special characters and formatting work
   - Validate that large datasets process efficiently

### Automated Testing (Minitest)
**Priority: Medium** - Focus on important cases as specified in project requirements.

**Model Tests:**
- ImportTemplate validations and methods
- DataRecord associations and validations
- Column definition JSON serialization

**Service Tests:**
- ExcelExportService file generation
- ExcelImportService data processing
- HeaderValidationService matching logic
- Error handling in all services

**Controller Tests:**
- Import/export action responses
- File upload handling
- Error message display
- Redirect behavior

### Edge Cases to Test

**File Format Edge Cases:**
- Very large Excel files (approaching 10MB limit)
- Excel files with multiple sheets (should use first sheet)
- Files with merged cells or complex formatting
- Files with formulas instead of values

**Data Type Edge Cases:**
- Numbers with various formats (1,000.50, €100, 50%)
- Dates in different formats (MM/DD/YYYY, DD-MM-YYYY, ISO)
- Boolean values (true/false, yes/no, 1/0, Y/N)
- Text with special characters and Unicode

**Validation Edge Cases:**
- Headers with extra spaces or different capitalization
- Required columns missing from Excel file
- Extra columns in Excel file not in template
- Completely empty Excel file or file with only headers

## Test Implementation Plan

### Phase 1: Manual Integration Testing
1. Start Rails server and test complete workflow
2. Create test templates with all data types
3. Export and import test files
4. Document any issues found

### Phase 2: Automated Test Creation
1. Write model tests for validations and relationships
2. Create service tests with mock Excel files
3. Add controller tests for import/export endpoints
4. Focus on critical path and error handling

### Phase 3: Bug Fixes and Refinement
1. Address issues found during testing
2. Improve error messages and user feedback
3. Optimize performance for larger files
4. Enhance UI/UX based on testing feedback

## Success Criteria

**Core Functionality:**
- [ ] User can create templates with 5 dynamic columns
- [ ] Excel export works for all 3 formats (template, data, sample)
- [ ] Excel import successfully processes valid files
- [ ] Header validation prevents invalid imports
- [ ] Data type conversion works correctly
- [ ] Error messages are clear and helpful

**Data Integrity:**
- [ ] Round-trip export/import preserves data accurately
- [ ] All data types (string, number, date, boolean) work correctly
- [ ] Large files (1000+ rows) process without errors
- [ ] Batch import creates proper import_batch_id grouping

**Error Handling:**
- [ ] Invalid file formats are rejected with clear messages
- [ ] Mismatched headers show helpful validation errors
- [ ] Row-level errors include line numbers for debugging
- [ ] Application remains stable during error conditions

**User Experience:**
- [ ] File upload provides visual feedback
- [ ] Export happens immediately without page reload
- [ ] Import results show clear success/failure summary
- [ ] Navigation between sections works smoothly

## Testing Tools and Setup

**Manual Testing:**
- Use Excel or LibreOffice Calc for file manipulation
- Test with various browsers (Chrome, Firefox, Safari)
- Create sample data sets of different sizes

**Automated Testing:**
- Use Rails default Minitest framework
- Create fixture files for test Excel documents
- Mock external dependencies where needed
- Use Rails test helpers for file uploads

**Performance Testing:**
- Test with Excel files of varying sizes (100, 1000, 5000 rows)
- Monitor memory usage during large imports
- Verify reasonable response times for all operations

## Risk Mitigation

**Identified Risks:**
1. **Excel compatibility issues** - Test with multiple Excel versions
2. **Memory issues with large files** - Implement streaming where possible
3. **Data type conversion errors** - Comprehensive edge case testing
4. **User confusion with header validation** - Clear error messages

**Mitigation Strategies:**
- Test with both .xls and .xlsx formats
- Set reasonable file size limits (10MB)
- Provide sample templates for users
- Include helpful validation error messages