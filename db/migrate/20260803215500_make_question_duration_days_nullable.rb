class MakeQuestionDurationDaysNullable < ActiveRecord::Migration[8.0]
  def change
    change_column_null :questions, :duration_days, true
    change_column_default :questions, :duration_days, from: 1, to: nil
  end
end
