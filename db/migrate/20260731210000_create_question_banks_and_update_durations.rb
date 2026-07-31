class CreateQuestionBanksAndUpdateDurations < ActiveRecord::Migration[8.0]
  def change
    create_table :question_banks do |t|
      t.string :name, null: false
      t.text :description
      t.boolean :active, default: true, null: false

      t.timestamps
    end

    add_reference :question_categories, :question_bank, foreign_key: true, null: true
    add_column :question_categories, :duration_days, :integer, default: 30, null: false
    add_column :questions, :duration_days, :integer, default: 1, null: false

    reversible do |dir|
      dir.up do
        execute <<~SQL
          INSERT INTO question_banks (name, description, active, created_at, updated_at)
          VALUES ('Default Question Bank', 'Default question bank for existing categories.', true, NOW(), NOW());
        SQL

        execute <<~SQL
          UPDATE question_categories
          SET question_bank_id = (SELECT id FROM question_banks ORDER BY id ASC LIMIT 1);
        SQL
      end
    end

    remove_column :question_categories, :start_date, :datetime
    remove_column :question_categories, :end_date, :datetime

    remove_column :questions, :start_date, :date
    remove_column :questions, :end_date, :date

    remove_column :question_bundles, :start_date, :date
    remove_column :question_bundles, :end_date, :date
  end
end
