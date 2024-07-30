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

ActiveRecord::Schema[7.1].define(version: 2024_07_28_031804) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "chat_summaries", force: :cascade do |t|
    t.bigint "chat_id", null: false
    t.integer "status", default: 0, null: false, comment: "0=running 1=complete"
    t.integer "summary_type", null: false, comment: "0=default 1=nice 2=vibe_check"
    t.integer "summary_message_api_id", comment: "api_id of the message where the bot sent this summary output"
    t.string "text"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["chat_id"], name: "index_chat_summaries_on_chat_id"
    t.index ["created_at"], name: "index_chat_summaries_on_created_at"
  end

  create_table "chat_users", force: :cascade do |t|
    t.bigint "chat_id", null: false
    t.bigint "user_id", null: false
    t.integer "num_chatuser_messages", default: 0, comment: "All-time count of messages sent by this ChatUser"
    t.integer "num_stored_messages", default: 0, comment: "Current number of messages from this ChatUser stored in the DB"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["chat_id", "user_id"], name: "index_chat_users_on_chat_id_and_user_id", unique: true
    t.index ["chat_id"], name: "index_chat_users_on_chat_id"
    t.index ["user_id"], name: "index_chat_users_on_user_id"
  end

  create_table "chats", force: :cascade do |t|
    t.bigint "api_id", null: false
    t.integer "api_type", null: false, comment: "0=private 1=group 2=supergroup 3=channel"
    t.string "title"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["api_id"], name: "index_chats_on_api_id"
  end

  create_table "messages", force: :cascade do |t|
    t.integer "api_id", null: false
    t.bigint "reply_to_message_id"
    t.bigint "chat_user_id", null: false
    t.integer "attachment_type", comment: "0=animation 1=audio 2=document 3=photo 4=video 5=voice"
    t.datetime "date"
    t.string "text"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["chat_user_id"], name: "index_messages_on_chat_user_id"
    t.index ["reply_to_message_id"], name: "index_messages_on_reply_to_message_id"
  end

  create_table "users", force: :cascade do |t|
    t.bigint "api_id", null: false
    t.string "first_name"
    t.string "username"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["api_id"], name: "index_users_on_api_id"
  end

  add_foreign_key "chat_summaries", "chats"
  add_foreign_key "chat_users", "chats"
  add_foreign_key "chat_users", "users"
  add_foreign_key "messages", "chat_users"
  add_foreign_key "messages", "messages", column: "reply_to_message_id"
end
