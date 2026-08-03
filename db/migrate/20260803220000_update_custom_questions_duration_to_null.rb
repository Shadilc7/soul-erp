class UpdateCustomQuestionsDurationToNull < ActiveRecord::Migration[8.0]
  def up
    Question.where(question_category_id: nil, duration_days: 1).update_all(duration_days: nil)
  end

  def down
  end
end
