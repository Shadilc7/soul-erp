class CreateTrainingProgramParticipants < ActiveRecord::Migration[8.0]
  def change
    create_table :training_program_participants do |t|
      t.references :training_program, null: false, foreign_key: true
      t.references :participant, null: false, foreign_key: true

      t.timestamps

      t.index [ :training_program_id, :participant_id ], unique: true, name: 'index_training_program_participants_uniqueness'
    end
  end
end
