class TrainingProgramFeedback < ApplicationRecord
  belongs_to :training_program, counter_cache: true
  belongs_to :participant

  validates :content, presence: true
  validates :rating, presence: true,
    numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 5 }
  validates :training_program_id, uniqueness: { scope: :participant_id,
    message: "feedback has already been submitted for this program" }

  scope :active, -> { where(active: true) }
end
