class UpdateAssignmentQuestionsUniqueIndex < ActiveRecord::Migration[8.0]
  def change
    remove_index :assignment_questions, name: "index_assignment_questions_uniqueness", if_exists: true
    add_index :assignment_questions, [:assignment_id, :question_id, :bundle_name], unique: true, name: "index_assignment_questions_uniqueness"
  end
end
