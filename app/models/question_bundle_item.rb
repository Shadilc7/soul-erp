class QuestionBundleItem < ApplicationRecord
  belongs_to :question_bundle
  belongs_to :question

  validates :question_id, uniqueness: { scope: :question_bundle_id, message: "is already in this bundle" }
end
