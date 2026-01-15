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

ActiveRecord::Schema[8.0].define(version: 2026_01_15_121204) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "moab_records", force: :cascade do |t|
    t.integer "version", null: false
    t.bigint "preserved_object_id", null: false
    t.bigint "moab_storage_root_id", null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.datetime "last_moab_validation", precision: nil
    t.datetime "last_checksum_validation", precision: nil
    t.bigint "size"
    t.integer "status", null: false
    t.datetime "last_version_audit", precision: nil
    t.string "status_details"
    t.bigint "from_moab_storage_root_id"
    t.index ["created_at"], name: "index_moab_records_on_created_at"
    t.index ["from_moab_storage_root_id"], name: "index_moab_records_on_from_moab_storage_root_id"
    t.index ["last_checksum_validation"], name: "index_moab_records_on_last_checksum_validation"
    t.index ["last_moab_validation"], name: "index_moab_records_on_last_moab_validation"
    t.index ["last_version_audit"], name: "index_moab_records_on_last_version_audit"
    t.index ["moab_storage_root_id"], name: "index_moab_records_on_moab_storage_root_id"
    t.index ["preserved_object_id", "moab_storage_root_id", "version"], name: "index_moab_record_on_po_and_storage_root_and_version", unique: true
    t.index ["preserved_object_id", "moab_storage_root_id"], name: "index_moab_record_on_po_and_storage_root_id", unique: true
    t.index ["preserved_object_id"], name: "index_moab_records_on_preserved_object_id", unique: true
    t.index ["status"], name: "index_moab_records_on_status"
    t.index ["updated_at"], name: "index_moab_records_on_updated_at"
  end

  create_table "moab_storage_roots", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.string "storage_location", null: false
    t.index ["name"], name: "index_moab_storage_roots_on_name", unique: true
    t.index ["storage_location"], name: "index_moab_storage_roots_on_storage_location", unique: true
  end

  create_table "preserved_objects", force: :cascade do |t|
    t.string "druid", null: false
    t.integer "current_version", null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.datetime "last_archive_audit", precision: nil
    t.index ["created_at"], name: "index_preserved_objects_on_created_at"
    t.index ["druid"], name: "index_preserved_objects_on_druid", unique: true
    t.index ["last_archive_audit"], name: "index_preserved_objects_on_last_archive_audit"
    t.index ["updated_at"], name: "index_preserved_objects_on_updated_at"
  end

  create_table "zip_endpoints", force: :cascade do |t|
    t.string "endpoint_name", null: false
    t.string "endpoint_node"
    t.string "storage_location"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["endpoint_name"], name: "index_zip_endpoints_on_endpoint_name", unique: true
  end

  create_table "zip_parts", force: :cascade do |t|
    t.bigint "size"
    t.bigint "zipped_moab_version_id", null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.string "md5", null: false
    t.string "suffix", null: false
    t.index ["zipped_moab_version_id", "suffix"], name: "index_zip_parts_on_zipped_moab_version_id_and_suffix", unique: true
    t.index ["zipped_moab_version_id"], name: "index_zip_parts_on_zipped_moab_version_id"
  end

  create_table "zipped_moab_versions", force: :cascade do |t|
    t.integer "version", null: false
    t.bigint "zip_endpoint_id", null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.bigint "preserved_object_id", null: false
    t.integer "status", default: 2, null: false
    t.datetime "status_updated_at", precision: nil
    t.integer "zip_parts_count"
    t.string "status_details"
    t.index ["preserved_object_id", "zip_endpoint_id", "version"], name: "index_unique_on_zipped_moab_versions", unique: true
    t.index ["preserved_object_id"], name: "index_zipped_moab_versions_on_preserved_object_id"
    t.index ["status"], name: "index_zipped_moab_versions_on_status"
    t.index ["status_updated_at"], name: "index_zipped_moab_versions_on_status_updated_at"
    t.index ["zip_endpoint_id"], name: "index_zipped_moab_versions_on_zip_endpoint_id"
  end

  add_foreign_key "moab_records", "moab_storage_roots"
  add_foreign_key "moab_records", "moab_storage_roots", column: "from_moab_storage_root_id"
  add_foreign_key "moab_records", "preserved_objects"
  add_foreign_key "zip_parts", "zipped_moab_versions"
  add_foreign_key "zipped_moab_versions", "preserved_objects"
  add_foreign_key "zipped_moab_versions", "zip_endpoints"
end
