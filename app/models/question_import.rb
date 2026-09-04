class QuestionImport < ApplicationRecord
  belongs_to :question_category
  belongs_to :user, optional: true

  has_one_attached :file

  enum :status, {
    pending: 0,
    processing: 1,
    completed: 2,
    failed: 3,
    partially_completed: 4
  }

  scope :ordered, -> { order(created_at: :desc) }
  scope :actual, -> { where(dry_run: false) }
  scope :dry_runs, -> { where(dry_run: true) }

  def success_rate
    return 0 if total_rows.zero?
    ((successful_rows.to_f / total_rows) * 100).round
  end

  def has_errors?
    failed_rows.positive? || (error_log.is_a?(Array) && error_log.any?)
  end

  def completed_or_failed?
    completed? || failed? || partially_completed?
  end

  def duration_seconds
    return 0 unless completed_or_failed? && created_at.present? && updated_at.present?
    [(updated_at - created_at).round, 0].max
  end
end
