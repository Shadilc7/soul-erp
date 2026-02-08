class AddTriggerToOptions < ActiveRecord::Migration[8.0]
  def up
    # Create a function that will be called by the trigger
    execute <<-SQL
      CREATE OR REPLACE FUNCTION ensure_option_text_not_null()
      RETURNS TRIGGER AS $$
      BEGIN
        IF NEW.text IS NULL THEN
          NEW.text := 'Option ' || extract(epoch from now())::bigint;
        END IF;
      #{'  '}
        -- Also ensure value is set for backward compatibility
        IF NEW.value IS NULL THEN
          NEW.value := NEW.text;
        END IF;
      #{'  '}
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;
    SQL

    # Create the trigger
    execute <<-SQL
      CREATE TRIGGER ensure_option_text_trigger
      BEFORE INSERT OR UPDATE ON options
      FOR EACH ROW
      EXECUTE FUNCTION ensure_option_text_not_null();
    SQL
  end

  def down
    execute <<-SQL
      DROP TRIGGER IF EXISTS ensure_option_text_trigger ON options;
      DROP FUNCTION IF EXISTS ensure_option_text_not_null();
    SQL
  end
end
