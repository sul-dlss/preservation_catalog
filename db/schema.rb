# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20180802230025) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "complete_moabs", force: :cascade do |t|
    t.integer "version", null: false
    t.bigint "preserved_object_id", null: false
    t.bigint "moab_storage_root_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "last_moab_validation"
    t.datetime "last_checksum_validation"
    t.bigint "size"
    t.integer "status", null: false
    t.datetime "last_version_audit"
    t.index ["created_at"], name: "index_complete_moabs_on_created_at"
    t.index ["last_checksum_validation"], name: "index_complete_moabs_on_last_checksum_validation"
    t.index ["last_moab_validation"], name: "index_complete_moabs_on_last_moab_validation"
    t.index ["last_version_audit"], name: "index_complete_moabs_on_last_version_audit"
    t.index ["moab_storage_root_id"], name: "index_complete_moabs_on_moab_storage_root_id"
    t.index ["preserved_object_id", "moab_storage_root_id", "version"], name: "index_preserved_copies_on_po_and_storage_root_and_version", unique: true
    t.index ["preserved_object_id"], name: "index_complete_moabs_on_preserved_object_id"
    t.index ["status"], name: "index_complete_moabs_on_status"
    t.index ["updated_at"], name: "index_complete_moabs_on_updated_at"
  end

  create_table "moab_storage_roots", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "storage_location", null: false
    t.index ["name"], name: "index_moab_storage_roots_on_name", unique: true
    t.index ["storage_location"], name: "index_moab_storage_roots_on_storage_location"
  end

  create_table "moab_storage_roots_preservation_policies", force: :cascade do |t|
    t.bigint "preservation_policy_id", null: false
    t.bigint "moab_storage_root_id", null: false
    t.index ["moab_storage_root_id"], name: "index_moab_storage_roots_pres_policies_on_moab_storage_root_id"
    t.index ["preservation_policy_id"], name: "index_moab_storage_roots_pres_policies_on_pres_policy_id"
  end

  create_table "preservation_policies", force: :cascade do |t|
    t.string "preservation_policy_name", null: false
    t.integer "archive_ttl", null: false
    t.integer "fixity_ttl", null: false
    t.index ["preservation_policy_name"], name: "index_preservation_policies_on_preservation_policy_name", unique: true
  end

  create_table "preservation_policies_zip_endpoints", force: :cascade do |t|
    t.bigint "preservation_policy_id", null: false
    t.bigint "zip_endpoint_id", null: false
    t.index ["preservation_policy_id"], name: "index_pres_policies_zip_endpoints_on_pres_policy_id"
    t.index ["zip_endpoint_id"], name: "index_pres_policies_zip_endpoints_on_zip_endpoint_id"
  end

  create_table "preserved_objects", force: :cascade do |t|
    t.string "druid", null: false
    t.integer "current_version", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "preservation_policy_id", null: false
    t.index ["created_at"], name: "index_preserved_objects_on_created_at"
    t.index ["druid"], name: "index_preserved_objects_on_druid", unique: true
    t.index ["preservation_policy_id"], name: "index_preserved_objects_on_preservation_policy_id"
    t.index ["updated_at"], name: "index_preserved_objects_on_updated_at"
  end

  create_table "zip_endpoints", force: :cascade do |t|
    t.string "endpoint_name", null: false
    t.integer "delivery_class", null: false
    t.string "endpoint_node"
    t.string "storage_location"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["endpoint_name"], name: "index_zip_endpoints_on_endpoint_name", unique: true
  end

  create_table "zip_parts", force: :cascade do |t|
    t.bigint "size"
    t.bigint "zipped_moab_version_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "md5", null: false
    t.string "create_info", null: false
    t.integer "parts_count", null: false
    t.string "suffix", null: false
    t.integer "status", default: 1, null: false
    t.datetime "last_existence_check"
    t.datetime "last_checksum_validation"
    t.index ["zipped_moab_version_id"], name: "index_zip_parts_on_zipped_moab_version_id"
  end

  create_table "zipped_moab_versions", force: :cascade do |t|
    t.integer "version", null: false
    t.bigint "complete_moab_id", null: false
    t.bigint "zip_endpoint_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["complete_moab_id"], name: "index_zipped_moab_versions_on_complete_moab_id"
    t.index ["zip_endpoint_id"], name: "index_zipped_moab_versions_on_zip_endpoint_id"
  end

  add_foreign_key "complete_moabs", "moab_storage_roots"
  add_foreign_key "complete_moabs", "preserved_objects"
  add_foreign_key "moab_storage_roots_preservation_policies", "moab_storage_roots"
  add_foreign_key "moab_storage_roots_preservation_policies", "preservation_policies"
  add_foreign_key "preservation_policies_zip_endpoints", "preservation_policies"
  add_foreign_key "preservation_policies_zip_endpoints", "zip_endpoints"
  add_foreign_key "preserved_objects", "preservation_policies"
  add_foreign_key "zip_parts", "zipped_moab_versions"
  add_foreign_key "zipped_moab_versions", "complete_moabs"
  add_foreign_key "zipped_moab_versions", "zip_endpoints"
end
