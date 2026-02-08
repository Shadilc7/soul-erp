class AddDefaultValueToOptionsText < ActiveRecord::Migration[8.0]
  def up
    # First, update any existing null values
    execute <<-SQL
      UPDATE options SET text = CONCAT('Option ', EXTRACT(EPOCH FROM NOW())::bigint) WHERE text IS NULL;
    SQL

    # Then add default value and not null constraint
    change_column_default :options, :text, 'Default Option'
    change_column_null :options, :text, false

    # Also update value column for backward compatibility
    execute <<-SQL
      UPDATE options SET value = text WHERE value IS NULL;
    SQL
  end

  def down
    change_column_default :options, :text, nil
    # We won't remove the not null constraint as it's important for data integrity
  end
end
