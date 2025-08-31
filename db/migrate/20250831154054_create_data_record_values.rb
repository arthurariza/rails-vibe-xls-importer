# frozen_string_literal: true

class CreateDataRecordValues < ActiveRecord::Migration[8.0]
  def change
    create_table :data_record_values do |t|
      t.references :data_record, null: false, foreign_key: true
      t.references :template_column, null: false, foreign_key: true
      t.text :value

      t.timestamps
    end

    add_index :data_record_values, %i[data_record_id template_column_id], unique: true
  end
end
