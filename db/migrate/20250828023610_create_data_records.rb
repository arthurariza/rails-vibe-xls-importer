# frozen_string_literal: true

class CreateDataRecords < ActiveRecord::Migration[8.0]
  def change
    create_table :data_records do |t|
      t.references :import_template, null: false, foreign_key: true
      t.text :column_1
      t.text :column_2
      t.text :column_3
      t.text :column_4
      t.text :column_5
      t.string :import_batch_id

      t.timestamps
    end
  end
end
