class GuardianStudentLink < ApplicationRecord
  belongs_to :guardian_participant, class_name: "Participant"
  belongs_to :student_participant, class_name: "Participant"

  validates :guardian_participant_id, uniqueness: { scope: :student_participant_id }
end
