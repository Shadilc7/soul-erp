class TrainingProgramParticipant < ApplicationRecord
  belongs_to :training_program
  belongs_to :participant

  validates :training_program_id, uniqueness: { scope: :participant_id }
end
