class RemoveDefaultFromOptionsText < ActiveRecord::Migration[8.0]
  def up
    change_column_default :options, :text, from: "Default Option", to: nil
    change_column_null :options, :text, true

    execute <<-SQL
      DROP TRIGGER IF EXISTS ensure_option_text_trigger ON options;
      DROP FUNCTION IF EXISTS ensure_option_text_not_null();
    SQL
  end

  def down
    change_column_default :options, :text, from: nil, to: "Default Option"
    change_column_null :options, :text, false
  end
end
