class QuestionBundle < ApplicationRecord
  belongs_to :question_category
  has_many :question_bundle_items, -> { order(position: :asc) }, dependent: :destroy
  has_many :questions, through: :question_bundle_items

  validates :name, presence: true

  scope :ordered, -> { order(position: :asc, created_at: :asc) }
end
