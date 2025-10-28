class AddUniqueIndexToAssignmentResponses < ActiveRecord::Migration[6.1]
  def change
    # Prevent duplicate responses for the same assignment, participant, question and date
    add_index :assignment_responses, [ :assignment_id, :participant_id, :question_id, :response_date ], unique: true, name: 'index_assignment_responses_unique'
  end
end
