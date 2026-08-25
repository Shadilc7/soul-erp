class QuestionBank < ApplicationRecord
  has_many :question_categories, dependent: :destroy

  validates :name, presence: true

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(created_at: :desc) }

  before_destroy :check_associations_before_destroy, prepend: true

  def total_categories_count
    question_categories.master.count
  end

  def total_questions_count
    Question.where(question_category_id: question_categories.master.select(:id)).count
  end

  private

  def check_associations_before_destroy
    cat_ids = question_categories.pluck(:id)
    return if cat_ids.empty?

    used_by_assignments = QuestionCategory.where(id: cat_ids).joins(:assignments).pluck(:name)
    used_by_questions = QuestionCategory.where(id: cat_ids).joins(questions: :assignment_questions).pluck(:name)
    used_category_names = (used_by_assignments + used_by_questions).uniq

    if used_category_names.any?
      cat_names = used_category_names.join(", ")
      errors.add(:base, "Cannot delete Question Bank '#{name}' because #{'category'.pluralize(used_category_names.size)} '#{cat_names}' #{used_category_names.size == 1 ? 'is' : 'are'} being used in assignments.")
      throw :abort
    end
  end
end
