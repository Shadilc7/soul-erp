class UpdateAssignmentQuestionsUniqueIndex < ActiveRecord::Migration[8.0]
  def change
    remove_index :assignment_questions, name: "index_assignment_questions_uniqueness", if_exists: true

    reversible do |dir|
      dir.up do
        execute <<-SQL
          DELETE FROM assignment_questions a
          USING assignment_questions b
          WHERE a.id > b.id
            AND a.assignment_id = b.assignment_id
            AND a.question_id = b.question_id
            AND (a.bundle_name = b.bundle_name OR (a.bundle_name IS NULL AND b.bundle_name IS NULL));
        SQL
      end
    end

    add_index :assignment_questions, [:assignment_id, :question_id, :bundle_name], unique: true, name: "index_assignment_questions_uniqueness", if_not_exists: true
  end
end
