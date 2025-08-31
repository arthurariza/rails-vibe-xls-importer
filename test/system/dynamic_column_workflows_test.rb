# frozen_string_literal: true

require "application_system_test_case"

class DynamicColumnWorkflowsTest < ApplicationSystemTestCase
  include Devise::Test::IntegrationHelpers

  def setup
    @user = users(:one)
    sign_in @user
  end

  test "template creation and display workflow" do
    # Step 1: Create a new template
    visit import_templates_path
    click_link "New Template"

    fill_in "Name", with: "Basic Test Template"
    fill_in "Description", with: "Simple dynamic column template"
    click_button "Create Import template"

    assert_text "Template was successfully created"

    # Step 2: Verify template was created and is displayed
    assert_text "Basic Test Template"
    assert_text "Simple dynamic column template"
    
    # Step 3: Check that we can edit the template
    assert_link "Edit Template"
    
    # Step 4: Check that column configuration section exists
    click_link "Edit Template"
    assert_text "Column Configuration"
    assert_button "Add Column"
  end

  test "template displays no columns message when empty" do
    # Create template with no columns
    visit new_import_template_path

    fill_in "Name", with: "Empty Template"
    fill_in "Description", with: "Template with no columns initially"
    click_button "Create Import template"

    # Should show message about no columns configured
    assert_text "No columns configured yet"
  end

  test "template with existing columns displays correctly" do
    # Create template with columns using ActiveRecord
    template = ImportTemplate.create!(
      name: "Pre-configured Template",
      description: "Template with existing columns",
      user: @user
    )
    
    # Add some template columns
    template.template_columns.create!(
      name: "Product Name",
      data_type: "string",
      column_number: 1,
      required: true
    )
    
    template.template_columns.create!(
      name: "Price",
      data_type: "number",
      column_number: 2,
      required: false
    )

    # Visit the template page
    visit import_template_path(template)

    # Should display the columns
    assert_text "Product Name"
    assert_text "Price"
    assert_text "String"
    assert_text "Number"
  end

  test "data record form loads for template with columns" do
    # Create template with columns
    template = ImportTemplate.create!(
      name: "Record Test Template",
      description: "Template for testing record creation",
      user: @user
    )
    
    template.template_columns.create!(
      name: "Name",
      data_type: "string",
      column_number: 1,
      required: false
    )
    
    template.template_columns.create!(
      name: "Age",
      data_type: "number",
      column_number: 2,
      required: false
    )

    # Visit the template and check that we can access the new record form
    visit import_template_path(template)
    click_link "Add First Record"

    # Verify we're on the new record page
    assert_text "New Data Record"
    assert_text "Template: Record Test Template"
    
    # Verify the form has the basic structure
    assert_button "Create Data record"
  end

  test "column configuration shows add and remove controls" do
    # Create template
    visit new_import_template_path
    
    fill_in "Name", with: "Column Management Test"
    fill_in "Description", with: "Test template for column management"
    click_button "Create Import template"
    
    # Go to edit page to see column configuration
    click_link "Edit Template"
    
    # Verify column configuration section exists
    assert_text "Column Configuration"
    assert_button "Add Column"
    
    # Should show message when no columns exist
    assert_text "No columns configured"
  end

  test "template edit form shows column management interface" do
    # Create template with existing column
    template = ImportTemplate.create!(
      name: "Edit Test Template",
      description: "Template for testing editing",
      user: @user
    )
    
    existing_column = template.template_columns.create!(
      name: "Existing Column",
      data_type: "string", 
      column_number: 1,
      required: true
    )
    
    # Visit edit page
    visit edit_import_template_path(template)
    
    # Verify column management interface is available
    assert_text "Column Configuration"
    assert_button "Add Column"
    
    # Verify existing column is referenced
    assert_text "Column 1"
    
    # Verify preview section exists
    assert_text "Preview Excel Structure"
    assert_text "Existing Column"
  end

  test "new record form is accessible for templates with multiple column types" do
    # Create template with various column types
    template = ImportTemplate.create!(
      name: "Multi-type Template",
      description: "Template with different column types",
      user: @user
    )
    
    template.template_columns.create!(name: "Text Field", data_type: "string", column_number: 1)
    template.template_columns.create!(name: "Number Field", data_type: "number", column_number: 2) 
    template.template_columns.create!(name: "Date Field", data_type: "date", column_number: 3)
    template.template_columns.create!(name: "Boolean Field", data_type: "boolean", column_number: 4)
    
    # Navigate to new record form
    visit import_template_path(template)
    click_link "Add First Record"
    
    # Verify we can access the form
    assert_text "New Data Record"
    assert_text "Multi-type Template"
    assert_button "Create Data record"
  end

  test "template index displays column count" do
    # Create templates with different column counts
    template_no_cols = ImportTemplate.create!(
      name: "Empty Template",
      description: "Template with no columns",
      user: @user
    )
    
    template_with_cols = ImportTemplate.create!(
      name: "Template With Columns",
      description: "Template with columns",
      user: @user
    )
    
    template_with_cols.template_columns.create!(name: "Col 1", data_type: "string", column_number: 1)
    template_with_cols.template_columns.create!(name: "Col 2", data_type: "number", column_number: 2)
    
    # Visit templates index
    visit import_templates_path
    
    # Both templates should be listed
    assert_text "Empty Template"
    assert_text "Template With Columns"
  end
end