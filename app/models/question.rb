class Question < ApplicationRecord
  belongs_to :institute
  has_many :question_set_items, dependent: :restrict_with_error
  has_many :question_sets, through: :question_set_items
  has_many :options, dependent: :destroy
  accepts_nested_attributes_for :options, allow_destroy: true, reject_if: proc { |attributes|
    attributes["text"].blank? && attributes["_destroy"] != "1"
  }
  has_many :assignment_questions, dependent: :restrict_with_error
  has_many :assignments, through: :assignment_questions
  has_many :responses, class_name: "AssignmentResponse", dependent: :destroy

  validates :title, presence: true
  validates :question_type, presence: true
  validate :validate_options_and_answers, if: :should_validate_options?

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

  before_destroy :check_assignment_associations

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
end
