class AddFromDayAndToDayToQuestionsAndQuestionBundles < ActiveRecord::Migration[8.0]
  def change
    add_column :questions, :from_day, :integer, default: 1, null: false
    add_column :questions, :to_day, :integer

    add_column :question_bundles, :from_day, :integer, default: 1, null: false
    add_column :question_bundles, :to_day, :integer

    reversible do |dir|
      dir.up do
        # Backfill questions
        execute <<~SQL
          UPDATE questions
          SET from_day = 1,
              to_day = COALESCE(
                duration_days,
                (SELECT duration_days FROM question_categories WHERE question_categories.id = questions.question_category_id),
                30
              )
          WHERE to_day IS NULL;
        SQL

        # Backfill question_bundles
        execute <<~SQL
          UPDATE question_bundles
          SET from_day = 1,
              to_day = COALESCE(
                (SELECT duration_days FROM question_categories WHERE question_categories.id = question_bundles.question_category_id),
                30
              )
          WHERE to_day IS NULL;
        SQL
      end
    end
  end
end
