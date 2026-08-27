class BackfillQuestionBundleItemsPositions < ActiveRecord::Migration[8.0]
  def up
    QuestionBundle.find_each do |bundle|
      # Sort items by current position, then created_at, then id
      items = bundle.question_bundle_items.order(:position, :created_at, :id)
      items.each_with_index do |item, idx|
        expected_pos = idx + 1
        item.update_columns(position: expected_pos) if item.position != expected_pos
      end
    end
  end

  def down
    # Irreversible data migration, no-op
  end
end
