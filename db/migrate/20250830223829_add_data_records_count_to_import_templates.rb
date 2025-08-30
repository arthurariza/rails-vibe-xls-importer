# frozen_string_literal: true

class AddDataRecordsCountToImportTemplates < ActiveRecord::Migration[8.0]
  def change
    add_column :import_templates, :data_records_count, :integer, default: 0, null: false
  end
end
