# frozen_string_literal: true

class CreateTemplateColumns < ActiveRecord::Migration[8.0]
  def change
    create_table :template_columns do |t|
      t.references :import_template, null: false, foreign_key: true
      t.integer :column_number, null: false
      t.string :name, null: false
      t.string :data_type, null: false
      t.boolean :required, default: false, null: false

      t.timestamps
    end

    add_index :template_columns, %i[import_template_id column_number], unique: true
  end
end
