class AddOptionsCountToQuestions < ActiveRecord::Migration[8.0]
  def change
    add_column :questions, :options_count, :integer, default: 0, null: false

    reversible do |dir|
      dir.up do
        execute <<-SQL.squish
          UPDATE questions
          SET options_count = (
            SELECT COUNT(*)
            FROM options
            WHERE options.question_id = questions.id
          )
        SQL
      end
    end
  end
end
