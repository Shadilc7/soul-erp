class QuestionCategory < ApplicationRecord
  belongs_to :question_bank, optional: true
  has_many :questions, dependent: :destroy
  has_many :question_bundles, -> { order(position: :asc) }, dependent: :destroy

  validates :name, presence: true
  validates :duration_days, presence: true, numericality: { greater_than: 0 }

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(created_at: :desc) }

  def total_questions_count
    questions.count
  end

  def total_bundles_count
    question_bundles.count
  end
end
