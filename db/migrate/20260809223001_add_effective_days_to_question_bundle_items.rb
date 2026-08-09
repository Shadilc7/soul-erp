class AddEffectiveDaysToQuestionBundleItems < ActiveRecord::Migration[8.0]
  def change
    add_column :question_bundle_items, :effective_from_day, :integer
    add_column :question_bundle_items, :effective_to_day, :integer
  end
end
