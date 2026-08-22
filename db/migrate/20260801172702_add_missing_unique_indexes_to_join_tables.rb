class AddMissingUniqueIndexesToJoinTables < ActiveRecord::Migration[8.0]
  def up
    # Clean up duplicate participant-assignment associations before creating unique index
    execute <<-SQL
      DELETE FROM assignment_participants a
      USING assignment_participants b
      WHERE a.id > b.id
        AND a.assignment_id = b.assignment_id
        AND a.participant_id = b.participant_id;
    SQL

    # Prevent duplicate participant-assignment associations
    add_index :assignment_participants, [ :assignment_id, :participant_id ],
              unique: true,
              name: "index_assignment_participants_uniqueness",
              if_not_exists: true

    # Clean up duplicate question-assignment associations before creating unique index
    execute <<-SQL
      DELETE FROM assignment_questions a
      USING assignment_questions b
      WHERE a.id > b.id
        AND a.assignment_id = b.assignment_id
        AND a.question_id = b.question_id;
    SQL

    # Prevent duplicate question-assignment associations
    add_index :assignment_questions, [ :assignment_id, :question_id ],
              unique: true,
              name: "index_assignment_questions_uniqueness",
              if_not_exists: true

    # Clean up duplicate question_set-assignment associations before creating unique index
    execute <<-SQL
      DELETE FROM assignment_question_sets a
      USING assignment_question_sets b
      WHERE a.id > b.id
        AND a.assignment_id = b.assignment_id
        AND a.question_set_id = b.question_set_id;
    SQL

    # Prevent duplicate question_set-assignment associations
    add_index :assignment_question_sets, [ :assignment_id, :question_set_id ],
              unique: true,
              name: "index_assignment_question_sets_uniqueness",
              if_not_exists: true
  end

  def down
    remove_index :assignment_participants, name: "index_assignment_participants_uniqueness", if_exists: true
    remove_index :assignment_questions, name: "index_assignment_questions_uniqueness", if_exists: true
    remove_index :assignment_question_sets, name: "index_assignment_question_sets_uniqueness", if_exists: true
  end
end
