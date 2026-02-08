class Attendance < ApplicationRecord
  belongs_to :training_program
  belongs_to :participant
  belongs_to :marked_by, class_name: "User", optional: true

  enum :status, { present: 0, absent: 1, late: 2 }

  validates :date, presence: true
  validates :status, presence: true
  validates :participant_id,
    uniqueness: {
      scope: [ :training_program_id, :date ],
      message: "attendance already recorded for this date"
    }

  scope :by_date, ->(date) { where(date: date) }
  scope :present_statuses, -> { where(status: [ :present, :late ]) }
  scope :absent_statuses, -> { where(status: [ :absent ]) }

  validate :date_within_program_range

  # Calculate attendance percentage for a participant in a program
  def self.attendance_percentage(training_program_id, participant_id)
    total = where(training_program_id: training_program_id, participant_id: participant_id).count
    return 0 if total == 0

    present_count = where(training_program_id: training_program_id,
                          participant_id: participant_id,
                          status: [ :present, :late ]).count

    ((present_count.to_f / total) * 100).round
  end

  private

  def date_within_program_range
    return if date.blank? || training_program.nil?

    start_date = training_program.start_date&.to_date
    end_date = training_program.end_date&.to_date
    return if start_date.blank? || end_date.blank?

    if date < start_date || date > end_date
      errors.add(:date, "must be within the training program dates")
    end
  end
end
