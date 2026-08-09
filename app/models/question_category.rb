class QuestionCategory < ApplicationRecord
  belongs_to :question_bank, optional: true
  has_many :questions, dependent: :destroy
  has_many :question_bundles, -> { order(position: :asc) }, dependent: :destroy
  has_many :assignments, dependent: :restrict_with_error

  validates :name, presence: true
  validates :duration_days, presence: true, numericality: { greater_than: 0 }

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(created_at: :desc) }

  before_destroy :check_associations_before_destroy, prepend: true

  def total_questions_count
    questions.count
  end

  def total_bundles_count
    question_bundles.count
  end

  private

  def check_associations_before_destroy
    if assignments.exists?
      count = assignments.count
      errors.add(:base, "Cannot delete Question Category '#{name}' because it is being used in #{count} #{'assignment'.pluralize(count)}.")
      throw :abort
    end

    assigned_questions = questions.joins(:assignment_questions).distinct
    if assigned_questions.exists?
      count = assigned_questions.count
      errors.add(:base, "Cannot delete Question Category '#{name}' because #{count} of its #{'question'.pluralize(count)} #{count == 1 ? 'is' : 'are'} being used in assignments.")
      throw :abort
    end
  end
end
