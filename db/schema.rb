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

ActiveRecord::Schema.define(version: 20180711204251) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "archive_endpoints", force: :cascade do |t|
    t.string "endpoint_name", null: false
    t.integer "delivery_class", null: false
    t.string "endpoint_node"
    t.string "storage_location"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["endpoint_name"], name: "index_archive_endpoints_on_endpoint_name", unique: true
  end

  create_table "archive_endpoints_preservation_policies", force: :cascade do |t|
    t.bigint "preservation_policy_id", null: false
    t.bigint "archive_endpoint_id", null: false
    t.index ["archive_endpoint_id"], name: "index_archive_endpoints_pres_policies_on_archive_endpoint_id"
    t.index ["preservation_policy_id"], name: "index_archive_endpoints_pres_policies_on_pres_policy_id"
  end

  create_table "archive_preserved_copies", force: :cascade do |t|
    t.integer "version", null: false
    t.datetime "last_existence_check"
    t.bigint "preserved_copy_id", null: false
    t.bigint "archive_endpoint_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "status", null: false
    t.index ["archive_endpoint_id"], name: "index_archive_preserved_copies_on_archive_endpoint_id"
    t.index ["last_existence_check"], name: "index_archive_preserved_copies_on_last_existence_check"
    t.index ["preserved_copy_id"], name: "index_archive_preserved_copies_on_preserved_copy_id"
    t.index ["status"], name: "index_archive_preserved_copies_on_status"
  end

  create_table "archive_preserved_copy_parts", force: :cascade do |t|
    t.bigint "size"
    t.bigint "archive_preserved_copy_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "md5", null: false
    t.string "create_info", null: false
    t.integer "parts_count", null: false
    t.string "suffix", null: false
    t.integer "status", default: 1, null: false
    t.index ["archive_preserved_copy_id"], name: "index_archive_preserved_copy_parts_on_archive_preserved_copy_id"
  end

  create_table "endpoints", force: :cascade do |t|
    t.string "endpoint_name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "endpoint_node", null: false
    t.string "storage_location", null: false
    t.integer "delivery_class"
    t.index ["endpoint_name"], name: "index_endpoints_on_endpoint_name", unique: true
    t.index ["endpoint_node"], name: "index_endpoints_on_endpoint_node"
    t.index ["storage_location"], name: "index_endpoints_on_storage_location"
  end

  create_table "endpoints_preservation_policies", force: :cascade do |t|
    t.bigint "preservation_policy_id", null: false
    t.bigint "endpoint_id", null: false
    t.index ["endpoint_id"], name: "index_endpoints_preservation_policies_on_endpoint_id"
    t.index ["preservation_policy_id"], name: "index_endpoints_preservation_policies_on_preservation_policy_id"
  end

  create_table "preservation_policies", force: :cascade do |t|
    t.string "preservation_policy_name", null: false
    t.integer "archive_ttl", null: false
    t.integer "fixity_ttl", null: false
    t.index ["preservation_policy_name"], name: "index_preservation_policies_on_preservation_policy_name", unique: true
  end

  create_table "preserved_copies", force: :cascade do |t|
    t.integer "version", null: false
    t.bigint "preserved_object_id", null: false
    t.bigint "endpoint_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "last_moab_validation"
    t.datetime "last_checksum_validation"
    t.bigint "size"
    t.integer "status", null: false
    t.datetime "last_version_audit"
    t.index ["created_at"], name: "index_preserved_copies_on_created_at"
    t.index ["endpoint_id"], name: "index_preserved_copies_on_endpoint_id"
    t.index ["last_checksum_validation"], name: "index_preserved_copies_on_last_checksum_validation"
    t.index ["last_moab_validation"], name: "index_preserved_copies_on_last_moab_validation"
    t.index ["last_version_audit"], name: "index_preserved_copies_on_last_version_audit"
    t.index ["preserved_object_id", "endpoint_id", "version"], name: "index_preserved_copies_on_po_and_endpoint_and_version", unique: true
    t.index ["preserved_object_id"], name: "index_preserved_copies_on_preserved_object_id"
    t.index ["status"], name: "index_preserved_copies_on_status"
    t.index ["updated_at"], name: "index_preserved_copies_on_updated_at"
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

  add_foreign_key "archive_endpoints_preservation_policies", "archive_endpoints"
  add_foreign_key "archive_endpoints_preservation_policies", "preservation_policies"
  add_foreign_key "archive_preserved_copies", "archive_endpoints"
  add_foreign_key "archive_preserved_copies", "preserved_copies"
  add_foreign_key "archive_preserved_copy_parts", "archive_preserved_copies"
  add_foreign_key "endpoints_preservation_policies", "endpoints"
  add_foreign_key "endpoints_preservation_policies", "preservation_policies"
  add_foreign_key "preserved_copies", "endpoints"
  add_foreign_key "preserved_copies", "preserved_objects"
  add_foreign_key "preserved_objects", "preservation_policies"
end
