class Assignment < ApplicationRecord
  attr_accessor :skip_association_validation

  belongs_to :institute
  belongs_to :section, optional: true

  has_many :assignment_sections, dependent: :destroy
  has_many :sections, through: :assignment_sections

  has_many :assignment_participants, dependent: :destroy
  has_many :participants, through: :assignment_participants

  has_many :assignment_questions, dependent: :destroy
  has_many :questions, through: :assignment_questions

  has_many :assignment_question_sets, dependent: :destroy
  has_many :question_sets, through: :assignment_question_sets

  has_many :assignment_responses, dependent: :destroy
  has_many :assignment_response_logs, dependent: :destroy

  validates :title, presence: true
  validates :start_date, presence: true
  validates :end_date, presence: true
  validates :assignment_type, presence: true, inclusion: { in: [ "individual", "section" ] }

  validate :end_date_after_start_date
  validate :validate_associations

  accepts_nested_attributes_for :assignment_sections, allow_destroy: true
  accepts_nested_attributes_for :assignment_participants, allow_destroy: true
  accepts_nested_attributes_for :assignment_questions, allow_destroy: true
  accepts_nested_attributes_for :assignment_question_sets, allow_destroy: true

  scope :active, -> { where(active: true) }
  scope :current, -> { active.where("start_date <= ? AND end_date >= ?", Time.current, Time.current) }
  scope :upcoming, -> { active.where("start_date > ?", Time.current) }
  scope :past, -> { active.where("end_date < ?", Time.current) }
  scope :for_date, ->(date) {
    where("DATE(start_date) <= :date AND DATE(end_date) >= :date", date: date)
  }

  scope :for_participant, ->(participant) {
    select("assignments.*")
      .active
      .joins("LEFT JOIN assignment_participants ON assignments.id = assignment_participants.assignment_id")
      .joins("LEFT JOIN assignment_sections ON assignments.id = assignment_sections.assignment_id")
      .where("assignment_participants.participant_id = :participant_id OR assignment_sections.section_id = :section_id",
        participant_id: participant.id,
        section_id: participant.section_id)
      .distinct
  }

  def self.permitted_attributes
    [
      :title, :description, :start_date, :end_date,
      :assignment_type, :section_id,
      section_ids: [], participant_ids: [],
      question_ids: [], question_set_ids: []
    ]
  end

  def available_for?(participant)
    return false unless active?
    return false if Date.current < start_date || Date.current > end_date

    if assignment_type == "individual"
      participants.include?(participant)
    else
      sections.include?(participant.section)
    end
  end

  def answered_by?(participant)
    questions_count = questions.count + question_sets.sum { |qs| qs.questions.count }
    assignment_responses.where(participant: participant).count == questions_count
  end

  def answered_by_on_date?(participant, selected_date)
    assignment_responses.exists?(
      participant: participant,
      response_date: selected_date
    )
  end

  def available_for_date?(participant, date)
    return false unless active?
    return false if date > Date.current # Can't do future dates
    return false if date < start_date || date > end_date
    return false if answered_by_on_date?(participant, date)

    if assignment_type == "individual"
      participants.include?(participant)
    else
      sections.include?(participant.section)
    end
  end

  def total_days
    (end_date.to_date - start_date.to_date).to_i + 1
  end

  def completed_days(participant)
    assignment_responses
      .where(participant: participant)
      .distinct
      .pluck("DATE(response_date)")
      .count
  end

  def completion_percentage(participant)
    ((completed_days(participant).to_f / total_days) * 100).round(2)
  end

  def days_remaining
    [ (end_date.to_date - Date.current).to_i + 1, 0 ].max
  end

  def missed_days(participant)
    return 0 if Date.current <= start_date

    expected_days = [ (Date.current - start_date.to_date).to_i + 1, total_days ].min
    expected_days - completed_days(participant)
  end

  def all_questions
    # Combine direct questions and questions from question sets
    questions.order(:created_at) +
    question_sets.includes(:questions).flat_map { |qs| qs.questions.order(:created_at) }
  end

  def status
    return "inactive" unless active?

    if Time.current < start_date
      "upcoming"
    elsif Time.current > end_date
      "completed"
    else
      "active"
    end
  end

  private

  def validate_associations
    if persisted? # Only validate associations after initial save
      if questions.empty? && question_sets.empty?
        errors.add(:base, "Must have at least one question or question set")
      end

      if assignment_type == "section"
        if section_id.blank? && sections.empty?
          errors.add(:base, "Must select at least one section")
        end
      elsif assignment_type == "individual" && participants.empty?
        errors.add(:base, "Must select at least one participant")
      end
    end
  end

  def end_date_after_start_date
    return if end_date.blank? || start_date.blank?
    if end_date < start_date
      errors.add(:end_date, "must be after start date")
    end
  end
end
