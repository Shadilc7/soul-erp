class QuestionBundleItem < ApplicationRecord
  belongs_to :question_bundle
  belongs_to :question

  validates :question_id, uniqueness: { scope: :question_bundle_id, message: "is already in this bundle" }

  validate :validate_day_range_overlap
  before_save :calculate_effective_days

  def days_in_bundle
    return 0 if effective_from_day.blank? || effective_to_day.blank? || effective_to_day < effective_from_day
    (effective_to_day - effective_from_day + 1)
  end

  def effective_day_range_text
    return question&.day_range_text if effective_from_day.blank? || effective_to_day.blank?

    if effective_from_day == effective_to_day
      "Day #{effective_from_day.ordinalize}"
    else
      "Day #{effective_from_day.ordinalize} - #{effective_to_day.ordinalize} Day"
    end
  end

  def day_range_in_bundle_text
    count = days_in_bundle
    return "#{count} #{'day'.pluralize(count)}" if effective_from_day.blank? || effective_to_day.blank?
    if effective_from_day == effective_to_day
      "Day #{effective_from_day.ordinalize} (#{count} #{'day'.pluralize(count)})"
    else
      "Day #{effective_from_day.ordinalize}-#{effective_to_day.ordinalize} Day (#{count} #{'day'.pluralize(count)})"
    end
  end

  private

  def validate_day_range_overlap
    return unless question && question_bundle

    q_from = question.from_day || 1
    q_to = question.to_day || question.question_category&.duration_days || 30

    b_from = question_bundle.from_day || 1
    b_to = question_bundle.to_day || question_bundle.question_category&.duration_days || 30

    overlap_from = [q_from, b_from].max
    overlap_to = [q_to, b_to].min

    if overlap_from > overlap_to
      errors.add(:base, "Question schedule (#{question.day_range_text}) does not overlap with bundle schedule (#{question_bundle.day_range_text})")
    end
  end

  def calculate_effective_days
    return unless question && question_bundle

    q_from = question.from_day || 1
    q_to = question.to_day || question.question_category&.duration_days || 30

    b_from = question_bundle.from_day || 1
    b_to = question_bundle.to_day || question_bundle.question_category&.duration_days || 30

    self.effective_from_day = [q_from, b_from].max
    self.effective_to_day = [q_to, b_to].min
  end
end
