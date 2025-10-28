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

ActiveRecord::Schema[8.0].define(version: 2025_10_19_140229) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "assignment_participants", force: :cascade do |t|
    t.bigint "assignment_id", null: false
    t.bigint "participant_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["assignment_id"], name: "index_assignment_participants_on_assignment_id"
    t.index ["participant_id"], name: "index_assignment_participants_on_participant_id"
  end

  create_table "assignment_question_sets", force: :cascade do |t|
    t.bigint "assignment_id", null: false
    t.bigint "question_set_id", null: false
    t.integer "order_number"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["assignment_id"], name: "index_assignment_question_sets_on_assignment_id"
    t.index ["question_set_id"], name: "index_assignment_question_sets_on_question_set_id"
  end

  create_table "assignment_questions", force: :cascade do |t|
    t.bigint "assignment_id", null: false
    t.bigint "question_id", null: false
    t.integer "order_number"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["assignment_id"], name: "index_assignment_questions_on_assignment_id"
    t.index ["question_id"], name: "index_assignment_questions_on_question_id"
  end

  create_table "assignment_response_logs", force: :cascade do |t|
    t.bigint "institute_id", null: false
    t.bigint "participant_id", null: false
    t.datetime "response_date"
    t.bigint "assignment_id", null: false
    t.jsonb "assignment_response_ids", default: []
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "response_count"
    t.index ["assignment_id"], name: "index_assignment_response_logs_on_assignment_id"
    t.index ["institute_id"], name: "index_assignment_response_logs_on_institute_id"
    t.index ["participant_id"], name: "index_assignment_response_logs_on_participant_id"
  end

  create_table "assignment_responses", force: :cascade do |t|
    t.bigint "assignment_id", null: false
    t.bigint "participant_id", null: false
    t.bigint "question_id", null: false
    t.text "answer"
    t.jsonb "selected_options"
    t.datetime "submitted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.date "response_date"
    t.index ["assignment_id", "participant_id", "question_id", "response_date"], name: "index_assignment_responses_unique", unique: true
    t.index ["assignment_id"], name: "index_assignment_responses_on_assignment_id"
    t.index ["participant_id"], name: "index_assignment_responses_on_participant_id"
    t.index ["question_id"], name: "index_assignment_responses_on_question_id"
    t.index ["response_date"], name: "index_assignment_responses_on_response_date"
  end

  create_table "assignment_sections", force: :cascade do |t|
    t.bigint "assignment_id", null: false
    t.bigint "section_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["assignment_id"], name: "index_assignment_sections_on_assignment_id"
    t.index ["section_id"], name: "index_assignment_sections_on_section_id"
  end

  create_table "assignments", force: :cascade do |t|
    t.bigint "institute_id", null: false
    t.string "title", null: false
    t.text "description"
    t.datetime "start_date", null: false
    t.datetime "end_date", null: false
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "assignment_type", default: "individual"
    t.integer "section_id"
    t.index ["institute_id"], name: "index_assignments_on_institute_id"
    t.index ["section_id"], name: "index_assignments_on_section_id"
  end

  create_table "attendances", force: :cascade do |t|
    t.bigint "training_program_id", null: false
    t.bigint "participant_id", null: false
    t.bigint "marked_by_id", null: false
    t.date "date", null: false
    t.integer "status", default: 0, null: false
    t.text "remarks"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["marked_by_id"], name: "index_attendances_on_marked_by_id"
    t.index ["participant_id"], name: "index_attendances_on_participant_id"
    t.index ["training_program_id", "participant_id", "date"], name: "index_attendances_uniqueness", unique: true
    t.index ["training_program_id"], name: "index_attendances_on_training_program_id"
  end

  create_table "certificate_configurations", force: :cascade do |t|
    t.string "name"
    t.text "details"
    t.integer "duration_period"
    t.bigint "institute_id", null: false
    t.integer "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "eligible_criteria"
    t.string "certificate_left_footer"
    t.string "certificate_right_footer"
    t.index ["institute_id"], name: "index_certificate_configurations_on_institute_id"
  end

  create_table "guardians", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "participant_id", null: false
    t.string "relation"
    t.string "contact_number"
    t.string "occupation"
    t.text "address"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["participant_id"], name: "index_guardians_on_participant_id"
    t.index ["user_id"], name: "index_guardians_on_user_id"
  end

  create_table "individual_certificates", force: :cascade do |t|
    t.bigint "participant_id", null: false
    t.bigint "assignment_id", null: false
    t.bigint "certificate_configuration_id", null: false
    t.bigint "institute_id", null: false
    t.string "filename"
    t.datetime "generated_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "published"
    t.text "chart_image_data"
    t.index ["assignment_id"], name: "index_individual_certificates_on_assignment_id"
    t.index ["certificate_configuration_id"], name: "index_individual_certificates_on_certificate_configuration_id"
    t.index ["institute_id"], name: "index_individual_certificates_on_institute_id"
    t.index ["participant_id"], name: "index_individual_certificates_on_participant_id"
  end

  create_table "institutes", force: :cascade do |t|
    t.string "name"
    t.string "code"
    t.text "description"
    t.string "address"
    t.string "contact_number"
    t.string "email"
    t.boolean "active"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "institution_type"
    t.string "registered_poc"
    t.date "service_started_on"
    t.string "owner_name"
    t.integer "age_of_service"
    t.string "billing_type"
    t.date "expiry_date"
    t.text "other_details"
  end

  create_table "options", force: :cascade do |t|
    t.bigint "question_id", null: false
    t.boolean "correct", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "value"
    t.string "text", default: "Default Option", null: false
    t.index ["question_id"], name: "index_options_on_question_id"
  end

  create_table "participants", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "section_id"
    t.bigint "institute_id", null: false
    t.date "date_of_birth"
    t.string "education_level"
    t.date "enrollment_date"
    t.integer "status", default: 0
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "phone_number"
    t.string "participant_type"
    t.string "job_role"
    t.string "qualification"
    t.integer "years_of_experience"
    t.integer "guardian_for_participant_id"
    t.text "address"
    t.string "pin_code"
    t.string "district"
    t.string "state"
    t.index ["institute_id"], name: "index_participants_on_institute_id"
    t.index ["phone_number"], name: "index_participants_on_phone_number"
    t.index ["section_id"], name: "index_participants_on_section_id"
    t.index ["user_id"], name: "index_participants_on_user_id"
  end

  create_table "question_set_items", force: :cascade do |t|
    t.bigint "question_set_id", null: false
    t.bigint "question_id", null: false
    t.integer "order_number"
    t.integer "marks_override"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["question_id"], name: "index_question_set_items_on_question_id"
    t.index ["question_set_id"], name: "index_question_set_items_on_question_set_id"
  end

  create_table "question_sets", force: :cascade do |t|
    t.bigint "institute_id", null: false
    t.string "title", null: false
    t.text "description"
    t.integer "total_marks"
    t.integer "duration_minutes"
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["institute_id"], name: "index_question_sets_on_institute_id"
  end

  create_table "questions", force: :cascade do |t|
    t.bigint "institute_id", null: false
    t.string "title", null: false
    t.text "description"
    t.integer "question_type", default: 0, null: false
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "required", default: false
    t.integer "max_rating", default: 5
    t.string "display_name"
    t.index ["institute_id"], name: "index_questions_on_institute_id"
  end

  create_table "registration_settings", force: :cascade do |t|
    t.text "enabled_institutes", default: "--- []", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "sections", force: :cascade do |t|
    t.string "name"
    t.string "code"
    t.bigint "institute_id", null: false
    t.integer "capacity"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "status", default: 0, null: false
    t.index ["code", "institute_id"], name: "index_sections_on_code_and_institute_id", unique: true
    t.index ["institute_id"], name: "index_sections_on_institute_id"
  end

  create_table "trainers", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "institute_id", null: false
    t.string "specialization"
    t.string "qualification"
    t.integer "experience_years"
    t.text "bio"
    t.string "resume"
    t.json "certificates"
    t.integer "status", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "phone_number"
    t.text "experience_details"
    t.text "payment_details"
    t.text "other_details"
    t.index ["institute_id"], name: "index_trainers_on_institute_id"
    t.index ["phone_number"], name: "index_trainers_on_phone_number"
    t.index ["user_id"], name: "index_trainers_on_user_id"
  end

  create_table "training_program_feedbacks", force: :cascade do |t|
    t.bigint "training_program_id", null: false
    t.bigint "participant_id", null: false
    t.text "content", null: false
    t.integer "rating", null: false
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["participant_id"], name: "index_training_program_feedbacks_on_participant_id"
    t.index ["training_program_id", "participant_id"], name: "index_training_program_feedbacks_uniqueness", unique: true
    t.index ["training_program_id"], name: "index_training_program_feedbacks_on_training_program_id"
  end

  create_table "training_program_participants", force: :cascade do |t|
    t.bigint "training_program_id", null: false
    t.bigint "participant_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["participant_id"], name: "index_training_program_participants_on_participant_id"
    t.index ["training_program_id", "participant_id"], name: "index_training_program_participants_uniqueness", unique: true
    t.index ["training_program_id"], name: "index_training_program_participants_on_training_program_id"
  end

  create_table "training_program_sections", force: :cascade do |t|
    t.bigint "training_program_id", null: false
    t.bigint "section_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["section_id"], name: "index_training_program_sections_on_section_id"
    t.index ["training_program_id", "section_id"], name: "index_training_program_sections_uniqueness", unique: true
    t.index ["training_program_id"], name: "index_training_program_sections_on_training_program_id"
  end

  create_table "training_programs", force: :cascade do |t|
    t.bigint "institute_id", null: false
    t.bigint "trainer_id", null: false
    t.string "title", null: false
    t.text "description"
    t.datetime "start_date"
    t.datetime "end_date"
    t.integer "program_type", default: 0, null: false
    t.bigint "section_id"
    t.bigint "participant_id"
    t.integer "status", default: 0
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["institute_id", "program_type"], name: "index_training_programs_on_institute_id_and_program_type"
    t.index ["institute_id"], name: "index_training_programs_on_institute_id"
    t.index ["participant_id"], name: "index_training_programs_on_participant_id"
    t.index ["section_id"], name: "index_training_programs_on_section_id"
    t.index ["trainer_id"], name: "index_training_programs_on_trainer_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.string "username"
    t.integer "role"
    t.integer "institute_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "active", default: true
    t.bigint "section_id"
    t.string "first_name"
    t.string "last_name"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.string "phone"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["first_name", "last_name"], name: "index_users_on_first_name_and_last_name"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["section_id"], name: "index_users_on_section_id"
  end

  add_foreign_key "assignment_participants", "assignments"
  add_foreign_key "assignment_participants", "participants"
  add_foreign_key "assignment_question_sets", "assignments"
  add_foreign_key "assignment_question_sets", "question_sets"
  add_foreign_key "assignment_questions", "assignments"
  add_foreign_key "assignment_questions", "questions"
  add_foreign_key "assignment_response_logs", "assignments"
  add_foreign_key "assignment_response_logs", "institutes"
  add_foreign_key "assignment_response_logs", "participants"
  add_foreign_key "assignment_responses", "assignments"
  add_foreign_key "assignment_responses", "participants"
  add_foreign_key "assignment_responses", "questions"
  add_foreign_key "assignment_sections", "assignments"
  add_foreign_key "assignment_sections", "sections"
  add_foreign_key "assignments", "institutes"
  add_foreign_key "attendances", "participants"
  add_foreign_key "attendances", "training_programs"
  add_foreign_key "attendances", "users", column: "marked_by_id"
  add_foreign_key "certificate_configurations", "institutes"
  add_foreign_key "guardians", "participants"
  add_foreign_key "guardians", "users"
  add_foreign_key "individual_certificates", "assignments"
  add_foreign_key "individual_certificates", "certificate_configurations"
  add_foreign_key "individual_certificates", "institutes"
  add_foreign_key "individual_certificates", "participants"
  add_foreign_key "options", "questions"
  add_foreign_key "participants", "institutes"
  add_foreign_key "participants", "sections"
  add_foreign_key "participants", "users"
  add_foreign_key "question_set_items", "question_sets"
  add_foreign_key "question_set_items", "questions"
  add_foreign_key "question_sets", "institutes"
  add_foreign_key "questions", "institutes"
  add_foreign_key "sections", "institutes"
  add_foreign_key "trainers", "institutes"
  add_foreign_key "trainers", "users"
  add_foreign_key "training_program_feedbacks", "participants"
  add_foreign_key "training_program_feedbacks", "training_programs"
  add_foreign_key "training_program_participants", "participants"
  add_foreign_key "training_program_participants", "training_programs"
  add_foreign_key "training_program_sections", "sections"
  add_foreign_key "training_program_sections", "training_programs"
  add_foreign_key "training_programs", "institutes"
  add_foreign_key "training_programs", "participants"
  add_foreign_key "training_programs", "sections"
  add_foreign_key "training_programs", "trainers"
  add_foreign_key "users", "sections"
end
