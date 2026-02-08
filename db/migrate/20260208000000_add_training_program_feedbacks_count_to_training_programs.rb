class AddTrainingProgramFeedbacksCountToTrainingPrograms < ActiveRecord::Migration[8.0]
  def up
    add_column :training_programs, :training_program_feedbacks_count, :integer, null: false, default: 0

    execute <<~SQL.squish
      UPDATE training_programs
      SET training_program_feedbacks_count = sub.count
      FROM (
        SELECT training_program_id, COUNT(*) AS count
        FROM training_program_feedbacks
        GROUP BY training_program_id
      ) AS sub
      WHERE training_programs.id = sub.training_program_id
    SQL
  end

  def down
    remove_column :training_programs, :training_program_feedbacks_count
  end
end
