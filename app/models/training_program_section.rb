class TrainingProgramSection < ApplicationRecord
  belongs_to :training_program
  belongs_to :section

  validates :training_program_id, uniqueness: { scope: :section_id }
end
