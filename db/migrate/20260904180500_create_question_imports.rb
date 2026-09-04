class CreateQuestionImports < ActiveRecord::Migration[8.0]
  def change
    create_table :question_imports do |t|
      t.references :question_category, null: false, foreign_key: true
      t.references :user, null: true, foreign_key: true
      t.string :filename
      t.integer :file_size
      t.integer :status, default: 0, null: false
      t.integer :total_rows, default: 0, null: false
      t.integer :successful_rows, default: 0, null: false
      t.integer :failed_rows, default: 0, null: false
      t.jsonb :error_log, default: []
      t.jsonb :process_log, default: []
      t.jsonb :imported_question_ids, default: []
      t.boolean :auto_assign_bundles, default: true, null: false
      t.boolean :dry_run, default: false, null: false
      t.boolean :rollback_on_error, default: false, null: false

      t.timestamps
    end

    add_index :question_imports, :status
  end
end
