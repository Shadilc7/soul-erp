class AddMissingUniqueIndexesToJoinTables < ActiveRecord::Migration[8.0]
  def up

    # Prevent duplicate participant-assignment associations
    add_index :assignment_participants, [ :assignment_id, :participant_id ],
              unique: true,
              name: "index_assignment_participants_uniqueness"

    # Prevent duplicate question-assignment associations
    add_index :assignment_questions, [ :assignment_id, :question_id ],
              unique: true,
              name: "index_assignment_questions_uniqueness"

    # Prevent duplicate question_set-assignment associations
    add_index :assignment_question_sets, [ :assignment_id, :question_set_id ],
              unique: true,
              name: "index_assignment_question_sets_uniqueness"
  end

  def down
    remove_index :assignment_participants, name: "index_assignment_participants_uniqueness"
    remove_index :assignment_questions, name: "index_assignment_questions_uniqueness"
    remove_index :assignment_question_sets, name: "index_assignment_question_sets_uniqueness"
  end
end
