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

ActiveRecord::Schema.define(version: 20170823233217) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "endpoints", force: :cascade do |t|
    t.string "endpoint_name", null: false
    t.string "endpoint_type", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["endpoint_name"], name: "index_endpoints_on_endpoint_name"
    t.index ["endpoint_type"], name: "index_endpoints_on_endpoint_type"
  end

  create_table "preservation_copies", force: :cascade do |t|
    t.integer "current_version", null: false
    t.string "status"
    t.bigint "last_audited"
    t.bigint "preserved_object_id", null: false
    t.bigint "endpoint_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["endpoint_id"], name: "index_preservation_copies_on_endpoint_id"
    t.index ["last_audited"], name: "index_preservation_copies_on_last_audited"
    t.index ["preserved_object_id"], name: "index_preservation_copies_on_preserved_object_id"
  end

  create_table "preserved_objects", force: :cascade do |t|
    t.string "druid", null: false
    t.integer "current_version", null: false
    t.string "preservation_policy"
    t.integer "size"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["druid"], name: "index_preserved_objects_on_druid"
    t.index ["preservation_policy"], name: "index_preserved_objects_on_preservation_policy"
  end

  add_foreign_key "preservation_copies", "endpoints"
  add_foreign_key "preservation_copies", "preserved_objects"
end
