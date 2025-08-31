# frozen_string_literal: true

class MigrateExistingColumnData < ActiveRecord::Migration[8.0]
  def up
    # First, migrate column definitions from import_templates to template_columns
    puts "Migrating column definitions to template_columns..."

    connection.select_all("SELECT * FROM import_templates WHERE column_definitions IS NOT NULL AND column_definitions != ''").each do |template|
      next if template["column_definitions"].blank?

      column_defs = JSON.parse(template["column_definitions"])

      (1..5).each do |column_number|
        column_key = "column_#{column_number}"
        column_def = column_defs&.dig(column_key)

        next if column_def.blank?

        connection.execute(<<~SQL.squish)
          INSERT INTO template_columns (import_template_id, column_number, name, data_type, required, created_at, updated_at)
          VALUES (#{template['id']}, #{column_number}, '#{column_def['name']}', '#{column_def['data_type']}', #{column_def['required'] || false}, datetime('now'), datetime('now'))
        SQL
      end
    end

    # Second, migrate data from column_1-5 fields to data_record_values
    puts "Migrating data record values to normalized structure..."

    connection.select_all("SELECT * FROM data_records").each do |record|
      (1..5).each do |column_number|
        template_column_id = connection.select_value(<<~SQL.squish)
          SELECT id FROM template_columns#{' '}
          WHERE import_template_id = #{record['import_template_id']}#{' '}
          AND column_number = #{column_number}
        SQL

        next unless template_column_id

        column_value = record["column_#{column_number}"]
        next if column_value.blank?

        connection.execute(<<~SQL.squish)
          INSERT INTO data_record_values (data_record_id, template_column_id, value, created_at, updated_at)
          VALUES (#{record['id']}, #{template_column_id}, '#{column_value.gsub("'", "''")}', datetime('now'), datetime('now'))
        SQL
      end
    end

    puts "Migration completed successfully!"
  end

  def down
    # Remove all template columns and data record values
    puts "Reverting migration - removing template columns and data record values..."

    connection.execute("DELETE FROM data_record_values")
    connection.execute("DELETE FROM template_columns")

    puts "Migration reverted successfully!"
  end
end
