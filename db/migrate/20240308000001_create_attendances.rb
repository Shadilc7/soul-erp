class CreateAttendances < ActiveRecord::Migration[8.0]
  def change
    create_table :attendances do |t|
      t.references :training_program, null: false, foreign_key: true
      t.references :participant, null: false, foreign_key: true
      t.references :marked_by, null: false, foreign_key: { to_table: :users }
      t.date :date, null: false
      t.integer :status, null: false, default: 0
      t.text :remarks

      t.timestamps

      t.index [ :training_program_id, :participant_id, :date ], unique: true,
              name: 'index_attendances_uniqueness'
    end
  end
end
