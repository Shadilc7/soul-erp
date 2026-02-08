class QuestionSetItem < ApplicationRecord
  belongs_to :question_set
  belongs_to :question

  validates :order_number, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :marks_override, numericality: { greater_than: 0, allow_nil: true }

  before_validation :set_order_number, on: :create
  before_save :set_default_marks

  private

  def set_order_number
    return if order_number.present?
    max_order = question_set.question_set_items.maximum(:order_number) || -1
    self.order_number = max_order + 1
  end

  def set_default_marks
    self.marks_override = 1 if marks_override.nil?
  end
end
