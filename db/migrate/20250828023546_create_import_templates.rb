class CreateImportTemplates < ActiveRecord::Migration[8.0]
  def change
    create_table :import_templates do |t|
      t.string :name
      t.text :description
      t.text :column_definitions

      t.timestamps
    end
  end
end
