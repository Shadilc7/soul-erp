class AddInstituteIdToQuestionCategories < ActiveRecord::Migration[8.0]
  def change
    add_reference :question_categories, :institute, foreign_key: true, null: true, index: true
  end
end
