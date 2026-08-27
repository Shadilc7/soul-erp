class QuestionBundle < ApplicationRecord
  belongs_to :question_category
  has_many :question_bundle_items, -> { order(position: :asc, created_at: :asc, id: :asc) }, dependent: :destroy
  has_many :questions, -> { order("question_bundle_items.position ASC, question_bundle_items.created_at ASC, question_bundle_items.id ASC") }, through: :question_bundle_items

  validates :name, presence: true
  validates :from_day, numericality: { greater_than_or_equal_to: 1 }, allow_nil: true
  validate :validate_day_range
  validate :validate_no_bundle_overlap

  after_save :sync_question_bundle_items

  scope :ordered, -> { order(position: :asc, created_at: :asc, id: :asc) }

  def day_range_text
    f_day = from_day || 1
    t_day = to_day || question_category&.duration_days || 30
    if f_day == t_day
      "Day #{f_day}"
    else
      "Day #{f_day} - #{t_day}"
    end
  end

  private

  def validate_day_range
    return if from_day.blank? && to_day.blank?

    f_day = from_day || 1
    if to_day.present? && to_day < f_day
      errors.add(:to_day, "must be greater than or equal to From Day (#{f_day})")
    end

    if question_category.present? && question_category.duration_days.present?
      max_days = question_category.duration_days
      if f_day > max_days
        errors.add(:from_day, "cannot exceed category maximum duration of #{max_days} days")
      end
      if to_day.present? && to_day > max_days
        errors.add(:to_day, "cannot exceed category maximum duration of #{max_days} days")
      end
    end
  end

  def validate_no_bundle_overlap
    return unless question_category_id.present?
    return if from_day.blank? && to_day.blank?

    curr_f = from_day || 1
    curr_t = to_day || question_category&.duration_days || 30

    return if curr_f.blank? || curr_t.blank? || curr_t < curr_f

    other_bundles = QuestionBundle.where(question_category_id: question_category_id)
    other_bundles = other_bundles.where.not(id: id) if persisted?

    other_bundles.each do |other|
      other_f = other.from_day || 1
      other_t = other.to_day || other.question_category&.duration_days || 30

      if curr_f <= other_t && curr_t >= other_f
        errors.add(:base, "Bundle day range (#{curr_f} - #{curr_t}) overlaps with existing bundle '#{other.name}' (#{other.day_range_text})")
        break
      end
    end
  end

  def sync_question_bundle_items
    question_bundle_items.reload.each do |item|
      q_from = item.question.from_day || 1
      q_to = item.question.to_day || item.question.question_category&.duration_days || 30
      b_from = from_day || 1
      b_to = to_day || question_category&.duration_days || 30

      overlap_from = [q_from, b_from].max
      overlap_to = [q_to, b_to].min

      if overlap_from > overlap_to
        item.destroy
      else
        item.update_columns(
          effective_from_day: overlap_from,
          effective_to_day: overlap_to
        )
      end
    end
  end
end
