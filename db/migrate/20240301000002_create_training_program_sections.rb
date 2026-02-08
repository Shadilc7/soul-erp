class CreateTrainingProgramSections < ActiveRecord::Migration[8.0]
  def change
    create_table :training_program_sections do |t|
      t.references :training_program, null: false, foreign_key: true
      t.references :section, null: false, foreign_key: true

      t.timestamps

      t.index [ :training_program_id, :section_id ], unique: true, name: 'index_training_program_sections_uniqueness'
    end
  end
end
