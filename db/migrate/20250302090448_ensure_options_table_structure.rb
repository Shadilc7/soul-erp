class EnsureOptionsTableStructure < ActiveRecord::Migration[8.0]
  def change
    # Ensure text column exists and is not null
    change_column_null :options, :text, false

    # Add value column if it doesn't exist (for backward compatibility)
    unless column_exists?(:options, :value)
      add_column :options, :value, :string
    end

    # Add correct column if it doesn't exist
    unless column_exists?(:options, :correct)
      add_column :options, :correct, :boolean, default: false
    end

    # Copy text to value for backward compatibility if value is empty
    execute <<-SQL
      UPDATE options SET value = text WHERE value IS NULL;
    SQL
  end
end
