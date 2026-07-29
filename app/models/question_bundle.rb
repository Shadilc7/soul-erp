class QuestionBundle < ApplicationRecord
  belongs_to :question_category
  has_many :question_bundle_items, -> { order(position: :asc) }, dependent: :destroy
  has_many :questions, through: :question_bundle_items

  validates :name, presence: true

  scope :ordered, -> { order(position: :asc, created_at: :asc) }

  def duration_days
    return 0 if start_date.blank? || end_date.blank?
    (end_date - start_date).to_i + 1
  end

  private

  def end_date_after_start_date
    return if start_date.blank? || end_date.blank?

    if end_date < start_date
      errors.add(:end_date, "must be after or equal to the start date")
    end
  end

  def within_category_date_range
    return if question_category.blank? || question_category.start_date.blank? || question_category.end_date.blank? || start_date.blank? || end_date.blank?

    cat_start = question_category.start_date.to_date
    cat_end = question_category.end_date.to_date

    if start_date < cat_start
      errors.add(:start_date, "cannot be earlier than category start date (#{cat_start.strftime('%d/%m/%Y')})")
    end

    if end_date > cat_end
      errors.add(:end_date, "cannot be later than category end date (#{cat_end.strftime('%d/%m/%Y')})")
    end
  end
end
