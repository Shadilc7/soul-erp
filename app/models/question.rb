class Question < ApplicationRecord
  belongs_to :institute, optional: true
  belongs_to :question_category, optional: true

  has_many :question_bundle_items, dependent: :destroy
  has_many :question_bundles, through: :question_bundle_items
  has_many :question_set_items, dependent: :destroy
  has_many :question_sets, through: :question_set_items
  has_many :options, dependent: :destroy
  accepts_nested_attributes_for :options, allow_destroy: true, reject_if: proc { |attributes|
    attributes["text"].blank? && attributes["_destroy"] != "1"
  }
  has_many :assignment_questions, dependent: :destroy
  has_many :assignments, through: :assignment_questions
  has_many :responses, class_name: "AssignmentResponse", dependent: :destroy

  validates :title, presence: true
  validates :question_type, presence: true
  validates :from_day, numericality: { greater_than_or_equal_to: 1 }, allow_nil: true
  validate :validate_day_range
  validate :validate_options_and_answers, if: :should_validate_options?

  def duration_days
    if from_day.present? && to_day.present?
      [ (to_day - from_day + 1), 1 ].max
    else
      read_attribute(:duration_days)
    end
  end

  def day_range_text
    f_day = from_day || 1
    t_day = to_day || question_category&.duration_days || read_attribute(:duration_days)
    if f_day.present? && t_day.present?
      if f_day == t_day
        "Day #{f_day}"
      else
        "Day #{f_day} - #{t_day}"
      end
    else
      "All Days"
    end
  end

  # Add an attribute to control options validation
  attr_accessor :validate_options_on_save

  enum :question_type, {
    short_answer: 0,    # Text input for short answers
    paragraph: 1,       # Text area for longer answers
    multiple_choice: 2, # Radio buttons, single answer
    checkboxes: 3,      # Checkboxes, multiple answers
    dropdown: 4,        # Dropdown select, single answer
    date: 5,            # Date picker
    time: 6,            # Time picker
    rating: 7,          # Star rating
    number: 8,          # Number input
    yes_or_no: 9        # Yes/No radio buttons
  }

  # Add scope for active questions
  scope :active, -> { where(active: true) }

  before_destroy :check_assignment_associations, prepend: true
  after_save :sync_question_bundle_items

  def requires_options?
    multiple_choice? || checkboxes? || dropdown? || yes_or_no?
  end

  def formatted_options
    return [] unless options.any?
    options.ordered.pluck(:value)
  end

  # Add a method to determine if the question is a rating
  def rating?
    question_type == "rating"
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

  # Helper method to determine if options should be validated
  def should_validate_options?
    requires_options? && validate_options_on_save != false
  end

  def validate_options_and_answers
    if requires_options?
      if options.size < 2
        errors.add(:options, "must have at least 2 options")
      end

      # Ensure all options have text
      options.each do |option|
        if option.text.blank? && !option.marked_for_destruction?
          option.text = "Option #{Time.now.to_i}"
        end
      end
    end
  end

  def check_assignment_associations
    if assignments.exists?
      errors.add(:base, "This question cannot be deleted because it is being used in #{assignments.count} #{'assignment'.pluralize(assignments.count)}")
      throw :abort
    elsif question_sets.joins(:assignments).exists?
      errors.add(:base, "This question cannot be deleted because it is being used in question sets that are assigned to assignments")
      throw :abort
    end
  end

  def sync_question_bundle_items
    question_bundle_items.reload.each do |item|
      q_from = from_day || 1
      q_to = to_day || question_category&.duration_days || 30
      b_from = item.question_bundle.from_day || 1
      b_to = item.question_bundle.to_day || item.question_bundle.question_category&.duration_days || 30

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
