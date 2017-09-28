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

ActiveRecord::Schema.define(version: 20170928181349) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "endpoint_types", force: :cascade do |t|
    t.string "type_name", null: false
    t.string "endpoint_class", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "endpoints", force: :cascade do |t|
    t.string "endpoint_name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "endpoint_node", null: false
    t.string "storage_location", null: false
    t.integer "recovery_cost", null: false
    t.string "access_key"
    t.bigint "endpoint_type_id", null: false
    t.index ["endpoint_name"], name: "index_endpoints_on_endpoint_name"
    t.index ["endpoint_type_id"], name: "index_endpoints_on_endpoint_type_id"
  end

  create_table "endpoints_preservation_policies", force: :cascade do |t|
    t.bigint "preservation_policy_id", null: false
    t.bigint "endpoint_id", null: false
    t.index ["endpoint_id"], name: "index_endpoints_preservation_policies_on_endpoint_id"
    t.index ["preservation_policy_id"], name: "index_endpoints_preservation_policies_on_preservation_policy_id"
  end

  create_table "preservation_copies", force: :cascade do |t|
    t.integer "current_version", null: false
    t.bigint "last_audited"
    t.bigint "preserved_object_id", null: false
    t.bigint "endpoint_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "status_id", null: false
    t.datetime "last_checked_on_storage"
    t.datetime "last_checksum_validation"
    t.index ["endpoint_id"], name: "index_preservation_copies_on_endpoint_id"
    t.index ["last_audited"], name: "index_preservation_copies_on_last_audited"
    t.index ["preserved_object_id"], name: "index_preservation_copies_on_preserved_object_id"
    t.index ["status_id"], name: "index_preservation_copies_on_status_id"
  end

  create_table "preservation_policies", force: :cascade do |t|
    t.string "preservation_policy_name", null: false
    t.integer "archive_ttl", null: false
    t.integer "fixity_ttl", null: false
  end

  create_table "preserved_objects", force: :cascade do |t|
    t.string "druid", null: false
    t.integer "current_version", null: false
    t.integer "size"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "preservation_policy_id", null: false
    t.index ["druid"], name: "index_preserved_objects_on_druid"
    t.index ["preservation_policy_id"], name: "index_preserved_objects_on_preservation_policy_id"
  end

  create_table "statuses", force: :cascade do |t|
    t.string "status_text", null: false
  end

  add_foreign_key "endpoints", "endpoint_types"
  add_foreign_key "endpoints_preservation_policies", "endpoints"
  add_foreign_key "endpoints_preservation_policies", "preservation_policies"
  add_foreign_key "preservation_copies", "endpoints"
  add_foreign_key "preservation_copies", "preserved_objects"
  add_foreign_key "preservation_copies", "statuses"
  add_foreign_key "preserved_objects", "preservation_policies"
end
