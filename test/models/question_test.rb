require "test_helper"

class QuestionTest < ActiveSupport::TestCase
  test "allows duration_days to be nil for All Days" do
    question = Question.new(
      title: "Test Question",
      question_type: "short_answer",
      duration_days: nil
    )
    assert question.valid?
    assert_nil question.duration_days
  end

  test "accepts explicit duration_days" do
    question = Question.new(
      title: "Test Question",
      question_type: "short_answer",
      duration_days: 5
    )
    assert question.valid?
    assert_equal 5, question.duration_days
  end
end
