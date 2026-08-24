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
end
