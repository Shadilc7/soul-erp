class AddPositionToQuestions < ActiveRecord::Migration[8.0]
  def change
    add_column :questions, :position, :integer, default: 0
  end
end
