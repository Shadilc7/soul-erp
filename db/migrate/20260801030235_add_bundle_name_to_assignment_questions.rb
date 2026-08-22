class AddBundleNameToAssignmentQuestions < ActiveRecord::Migration[8.0]
  def change
    add_column :assignment_questions, :bundle_name, :string
  end
end
