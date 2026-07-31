class QuestionBank < ApplicationRecord
  has_many :question_categories, dependent: :destroy

  validates :name, presence: true

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(created_at: :desc) }

  def total_categories_count
    question_categories.count
  end

  def total_questions_count
    Question.where(question_category_id: question_categories.select(:id)).count
  end
end
