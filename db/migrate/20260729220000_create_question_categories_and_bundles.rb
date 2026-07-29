class CreateQuestionCategoriesAndBundles < ActiveRecord::Migration[8.0]
  def change
    create_table :question_categories do |t|
      t.string :name, null: false
      t.text :description
      t.datetime :start_date, null: false
      t.datetime :end_date, null: false
      t.boolean :active, default: true, null: false

      t.timestamps
    end

    create_table :question_bundles do |t|
      t.references :question_category, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.date :start_date, null: false
      t.date :end_date, null: false
      t.integer :position, default: 0

      t.timestamps
    end

    create_table :question_bundle_items do |t|
      t.references :question_bundle, null: false, foreign_key: true
      t.references :question, null: false, foreign_key: true
      t.integer :position, default: 0

      t.timestamps
    end

    add_index :question_bundle_items, [:question_bundle_id, :question_id], unique: true, name: "idx_qb_items_unique"

    change_column_null :questions, :institute_id, true
    add_reference :questions, :question_category, foreign_key: true
    add_column :questions, :start_date, :date
    add_column :questions, :end_date, :date
  end
end
