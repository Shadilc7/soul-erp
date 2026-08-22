class MakeBundleDatesNullable < ActiveRecord::Migration[8.0]
  def change
    change_column_null :question_bundles, :start_date, true
    change_column_null :question_bundles, :end_date, true
  end
end
