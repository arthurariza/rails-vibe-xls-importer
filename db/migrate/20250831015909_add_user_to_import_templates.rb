# frozen_string_literal: true

class AddUserToImportTemplates < ActiveRecord::Migration[8.0]
  def up
    add_reference :import_templates, :user, null: true, foreign_key: true

    # Create a default user for existing templates if none exist
    default_user = if User.none?
                     User.create!(
                       email: "admin@xls-importer.com",
                       password: "password123",
                       password_confirmation: "password123",
                       confirmed_at: Time.current
                     )
                   else
                     User.first
                   end

    # Assign existing import templates to the default user
    ImportTemplate.where(user_id: nil).update_all(user_id: default_user.id)

    # Now make the column non-null
    change_column_null :import_templates, :user_id, false
  end

  def down
    remove_reference :import_templates, :user, foreign_key: true
  end
end
