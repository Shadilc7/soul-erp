class AssignmentResponse < ApplicationRecord
  belongs_to :participant
  belongs_to :assignment
  belongs_to :question
  has_one :section, through: :participant

  validates :participant_id, presence: true
  validates :assignment_id, presence: true
  validates :question_id, presence: true
  validates :response_date, presence: true

  scope :ordered, -> { order(created_at: :desc) }

  validate :validate_response_format

  def correct?
    case question.question_type
    when "multiple_choice", "dropdown"
      # For multiple choice/dropdown, check if selected option matches any correct option
      selected_options.present? && question.options.where(value: selected_options.first, correct: true).exists?
    when "checkboxes"
      # For checkboxes, check if selected options match all correct options
      return false unless selected_options.present?
      correct_values = question.options.where(correct: true).pluck(:value)
      selected_options.sort == correct_values.sort
    when "short_answer", "paragraph"
      # For text answers, check if answer matches any correct option
      return false unless answer.present?
      question.options.where(correct: true).any? do |option|
        answer.downcase.strip == option.value.downcase.strip
      end
    when "rating"
      # For rating questions, any valid rating is considered correct
      selected_options.present? && selected_options.first.to_i.between?(1, 5)
    else
      false
    end
  end

  private

  def validate_response_format
    return unless question&.required?

    case question.question_type
    when "multiple_choice", "dropdown", "rating", "yes_or_no"
      errors.add(:answer, "must be present") if answer.blank?
    when "checkboxes"
      errors.add(:selected_options, "must be present") if selected_options.blank?
    when "short_answer", "paragraph", "number", "date", "time"
      errors.add(:answer, "must be present") if answer.blank?
    end
  end
end
