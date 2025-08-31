# frozen_string_literal: true

namespace :data do
  desc "Migrate existing import templates and data records to default admin user"
  task migrate_existing_data: :environment do
    puts "Starting migration of existing data to default admin user..."
    
    # Find or create admin user
    admin_user = User.find_or_create_by!(email: "admin@xls-importer.com") do |user|
      user.password = "password123"
      user.password_confirmation = "password123"
      user.confirmed_at = Time.current
    end
    
    puts "Admin user: #{admin_user.email}"
    
    # Find import templates without users
    orphaned_templates = ImportTemplate.where(user_id: nil)
    puts "Found #{orphaned_templates.count} import templates without users"
    
    if orphaned_templates.any?
      # Assign orphaned templates to admin user
      orphaned_templates.update_all(user_id: admin_user.id)
      puts "Assigned #{orphaned_templates.count} import templates to admin user"
      
      # Count associated data records (these don't need direct migration since they belong to templates)
      total_data_records = orphaned_templates.sum { |template| template.data_records.count }
      puts "These templates contain #{total_data_records} data records (automatically associated through templates)"
    else
      puts "No orphaned import templates found - all templates already have users assigned"
    end
    
    puts "Data migration completed!"
    puts "All import templates and their associated data records are now owned by: #{admin_user.email}"
  end

  desc "Create default admin user if it doesn't exist"
  task create_admin: :environment do
    admin_user = User.find_or_create_by!(email: "admin@xls-importer.com") do |user|
      user.password = "password123"
      user.password_confirmation = "password123"
      user.confirmed_at = Time.current
    end
    
    puts "Admin user ready: #{admin_user.email}"
  end

  desc "Show data ownership status"
  task show_ownership_status: :environment do
    puts "=== Data Ownership Status ==="
    puts "Total users: #{User.count}"
    puts "Total import templates: #{ImportTemplate.count}"
    puts "Import templates with users: #{ImportTemplate.where.not(user_id: nil).count}"
    puts "Import templates without users: #{ImportTemplate.where(user_id: nil).count}"
    puts "Total data records: #{DataRecord.count}"
    
    if ImportTemplate.where(user_id: nil).any?
      puts "\nOrphaned templates:"
      ImportTemplate.where(user_id: nil).each do |template|
        puts "- #{template.name} (#{template.data_records.count} records)"
      end
    end
    
    if User.any?
      puts "\nData by user:"
      User.includes(:import_templates).each do |user|
        template_count = user.import_templates.count
        record_count = user.data_records.count
        puts "- #{user.email}: #{template_count} templates, #{record_count} records"
      end
    end
  end
end