# frozen_string_literal: true

# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

Rails.logger.debug "Creating seed data..."

# Create default admin user
admin_user = User.find_or_create_by!(email: "admin@xls-importer.com") do |user|
  user.password = "password123"
  user.password_confirmation = "password123"
  user.confirmed_at = Time.current
end
Rails.logger.debug { "Created admin user: #{admin_user.email}" }

# Create demo user
demo_user = User.find_or_create_by!(email: "demo@xls-importer.com") do |user|
  user.password = "password123"
  user.password_confirmation = "password123"
  user.confirmed_at = Time.current
end
Rails.logger.debug { "Created demo user: #{demo_user.email}" }

# Create sample import templates for admin user
employee_template = ImportTemplate.find_or_create_by!(
  name: "Employee Data Template",
  user: admin_user
) do |template|
  template.description = "Template for importing employee information"
  template.column_definitions = {
    "column_1" => { "name" => "Employee Name", "data_type" => "string" },
    "column_2" => { "name" => "Department", "data_type" => "string" },
    "column_3" => { "name" => "Salary", "data_type" => "number" },
    "column_4" => { "name" => "Start Date", "data_type" => "date" },
    "column_5" => { "name" => "Active", "data_type" => "boolean" }
  }
end

# Create sample data records for employee template
if employee_template.data_records.empty?
  [
    { column_1: "John Smith", column_2: "Engineering", column_3: "75000", column_4: "2024-01-15", column_5: "true" },
    { column_1: "Jane Doe", column_2: "Marketing", column_3: "65000", column_4: "2023-06-01", column_5: "true" },
    { column_1: "Bob Johnson", column_2: "Sales", column_3: "55000", column_4: "2023-03-20", column_5: "false" },
    { column_1: "Alice Brown", column_2: "Engineering", column_3: "80000", column_4: "2022-11-10", column_5: "true" },
    { column_1: "Charlie Wilson", column_2: "HR", column_3: "60000", column_4: "2024-02-28", column_5: "true" }
  ].each do |record_data|
    employee_template.data_records.create!(record_data)
  end
  Rails.logger.debug { "Created #{employee_template.data_records.count} employee records" }
end

# Create product template for demo user
product_template = ImportTemplate.find_or_create_by!(
  name: "Product Catalog Template",
  user: demo_user
) do |template|
  template.description = "Template for importing product catalog"
  template.column_definitions = {
    "column_1" => { "name" => "Product Name", "data_type" => "string" },
    "column_2" => { "name" => "Category", "data_type" => "string" },
    "column_3" => { "name" => "Price", "data_type" => "number" },
    "column_4" => { "name" => "In Stock", "data_type" => "boolean" },
    "column_5" => { "name" => "Launch Date", "data_type" => "date" }
  }
end

# Create sample product data
if product_template.data_records.empty?
  [
    { column_1: "Wireless Headphones", column_2: "Electronics", column_3: "149.99", column_4: "true",
      column_5: "2024-01-01" },
    { column_1: "Coffee Mug", column_2: "Kitchen", column_3: "12.99", column_4: "true", column_5: "2023-12-15" },
    { column_1: "Desk Lamp", column_2: "Office", column_3: "45.50", column_4: "false", column_5: "2024-02-10" },
    { column_1: "Running Shoes", column_2: "Sports", column_3: "89.99", column_4: "true", column_5: "2023-11-20" }
  ].each do |record_data|
    product_template.data_records.create!(record_data)
  end
  Rails.logger.debug { "Created #{product_template.data_records.count} product records" }
end

Rails.logger.debug "Seed data creation completed!"
Rails.logger.debug "Admin user: admin@xls-importer.com / password123"
Rails.logger.debug "Demo user: demo@xls-importer.com / password123"
