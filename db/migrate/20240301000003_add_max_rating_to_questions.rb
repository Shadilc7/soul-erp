class AddMaxRatingToQuestions < ActiveRecord::Migration[8.0]
  def change
    add_column :questions, :max_rating, :integer, default: 5
  end
end
