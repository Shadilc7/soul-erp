class QuestionBank < ApplicationRecord
  has_many :question_categories, dependent: :destroy

  validates :name, presence: true

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(created_at: :desc) }

  before_destroy :check_associations_before_destroy, prepend: true

  def total_categories_count
    question_categories.count
  end

  def total_questions_count
    Question.where(question_category_id: question_categories.select(:id)).count
  end

  private

  def check_associations_before_destroy
    used_categories = question_categories.select do |cat|
      cat.assignments.exists? || cat.questions.joins(:assignment_questions).exists?
    end

    if used_categories.any?
      cat_names = used_categories.map(&:name).join(", ")
      errors.add(:base, "Cannot delete Question Bank '#{name}' because category '#{cat_names}' is being used in assignments.")
      throw :abort
    end
  end
end
