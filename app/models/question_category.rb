class QuestionCategory < ApplicationRecord
  has_many :questions, dependent: :destroy
  has_many :question_bundles, -> { order(position: :asc, start_date: :asc) }, dependent: :destroy

  validates :name, presence: true
  validates :start_date, presence: true
  validates :end_date, presence: true
  validate :end_date_after_start_date

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(start_date: :desc, created_at: :desc) }

  def total_questions_count
    questions.count
  end

  def total_bundles_count
    question_bundles.count
  end

  private

  def end_date_after_start_date
    return if start_date.blank? || end_date.blank?

    if end_date < start_date
      errors.add(:end_date, "must be after or equal to the start date")
    end
  end
end
