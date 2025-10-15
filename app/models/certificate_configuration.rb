class CertificateConfiguration < ApplicationRecord
  belongs_to :institute

  # Enum for status to track if configuration is active or inactive
  enum :status, {
    active: 0,
    inactive: 1
  }

  # Set default values
  after_initialize :set_default_values, if: :new_record?

  # Validations
  validates :name, presence: true
  validates :duration_period, presence: true, numericality: { greater_than_or_equal_to: 5, less_than_or_equal_to: 30, only_integer: true }
  validates :eligible_criteria, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }, allow_nil: true

  # Scopes
  scope :active, -> { where(status: :active) }
  scope :by_institute, ->(institute_id) { where(institute_id: institute_id) }

  # Methods
  def formatted_duration
    if duration_period == 1
      "1 day"
    else
      "#{duration_period} days"
    end
  end

  # Returns an array of interval labels based on the duration period
  def interval_labels(total_days)
    return [] if duration_period <= 0 || total_days <= 0

    intervals = []
    current_day = 1

    while current_day <= total_days
      end_day = [ current_day + duration_period - 1, total_days ].min
      intervals << "#{current_day.ordinalize}-#{end_day.ordinalize} day"
      current_day = end_day + 1
    end

    intervals
  end

  private

  def set_default_values
    self.status ||= :active
  end
end
