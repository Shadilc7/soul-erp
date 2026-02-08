class AddSectionIdToAssignments < ActiveRecord::Migration[7.0]
  def change
    add_column :assignments, :section_id, :integer
    add_index :assignments, :section_id
  end
end
