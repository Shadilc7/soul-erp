class CreateGuardianStudentLinks < ActiveRecord::Migration[8.0]
  def up
    create_table :guardian_student_links do |t|
      t.bigint :guardian_participant_id, null: false
      t.bigint :student_participant_id, null: false
      t.timestamps
    end

    add_index :guardian_student_links, :guardian_participant_id
    add_index :guardian_student_links, :student_participant_id
    add_index :guardian_student_links,
              [ :guardian_participant_id, :student_participant_id ],
              unique: true,
              name: "idx_guardian_student_unique"

    add_foreign_key :guardian_student_links, :participants,
                    column: :guardian_participant_id
    add_foreign_key :guardian_student_links, :participants,
                    column: :student_participant_id

    # Migrate existing single-student links into the join table
    execute <<~SQL
      INSERT INTO guardian_student_links
        (guardian_participant_id, student_participant_id, created_at, updated_at)
      SELECT id, guardian_for_participant_id, NOW(), NOW()
      FROM participants
      WHERE guardian_for_participant_id IS NOT NULL
      ON CONFLICT DO NOTHING
    SQL
  end

  def down
    drop_table :guardian_student_links
  end
end
