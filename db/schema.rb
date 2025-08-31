# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_08_31_154458) do
  create_table "data_record_values", force: :cascade do |t|
    t.integer "data_record_id", null: false
    t.integer "template_column_id", null: false
    t.text "value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["data_record_id", "template_column_id"], name: "idx_on_data_record_id_template_column_id_45806ce0b0", unique: true
    t.index ["data_record_id"], name: "index_data_record_values_on_data_record_id"
    t.index ["template_column_id"], name: "index_data_record_values_on_template_column_id"
  end

  create_table "data_records", force: :cascade do |t|
    t.integer "import_template_id", null: false
    t.text "column_1"
    t.text "column_2"
    t.text "column_3"
    t.text "column_4"
    t.text "column_5"
    t.string "import_batch_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["import_template_id"], name: "index_data_records_on_import_template_id"
  end

  create_table "import_templates", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.text "column_definitions"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "data_records_count", default: 0, null: false
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_import_templates_on_user_id"
  end

  create_table "template_columns", force: :cascade do |t|
    t.integer "import_template_id", null: false
    t.integer "column_number", null: false
    t.string "name", null: false
    t.string "data_type", null: false
    t.boolean "required", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["import_template_id", "column_number"], name: "index_template_columns_on_import_template_id_and_column_number", unique: true
    t.index ["import_template_id"], name: "index_template_columns_on_import_template_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string "unconfirmed_email"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "data_record_values", "data_records"
  add_foreign_key "data_record_values", "template_columns"
  add_foreign_key "data_records", "import_templates"
  add_foreign_key "import_templates", "users"
  add_foreign_key "template_columns", "import_templates"
end
