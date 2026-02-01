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

ActiveRecord::Schema[8.0].define(version: 2026_02_01_091500) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "email_verifications", force: :cascade do |t|
    t.string "email"
    t.string "code_digest"
    t.datetime "expires_at"
    t.datetime "used_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "payload", default: {}, null: false
    t.integer "failed_attempts", default: 0, null: false
  end

  create_table "refresh_tokens", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "token_digest"
    t.datetime "expires_at"
    t.datetime "revoked_at"
    t.datetime "last_used_at"
    t.string "user_agent"
    t.string "ip_address"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_refresh_tokens_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "first_name"
    t.string "last_name"
    t.string "preferred_name"
    t.string "username"
    t.string "email"
    t.string "password_digest"
    t.datetime "last_login_at"
    t.datetime "locked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "failed_login_attempts", default: 0, null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  add_foreign_key "refresh_tokens", "users"
end
