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

  test "validates from_day and to_day range and category ceiling" do
    category = QuestionCategory.create!(name: "Test Category", duration_days: 30)

    valid_q = category.questions.build(
      title: "Valid Range Q",
      question_type: "short_answer",
      from_day: 1,
      to_day: 15
    )
    assert valid_q.valid?
    assert_equal 15, valid_q.duration_days

    invalid_ceiling_q = category.questions.build(
      title: "Exceeds Ceiling Q",
      question_type: "short_answer",
      from_day: 1,
      to_day: 35
    )
    assert_not invalid_ceiling_q.valid?
    assert_includes invalid_ceiling_q.errors[:to_day], "cannot exceed category maximum duration of 30 days"

    invalid_range_q = category.questions.build(
      title: "Invalid Range Q",
      question_type: "short_answer",
      from_day: 10,
      to_day: 5
    )
    assert_not invalid_range_q.valid?
    assert_includes invalid_range_q.errors[:to_day], "must be greater than or equal to From Day (10)"
  end

  test "orders questions with latest created first at the top" do
    category = QuestionCategory.create!(name: "Order Test Category", duration_days: 30)
    q1 = category.questions.create!(title: "First Question", question_type: "short_answer", created_at: 2.hours.ago)
    q2 = category.questions.create!(title: "Second Question", question_type: "short_answer", created_at: 1.hour.ago)
    q3 = category.questions.create!(title: "Third Question", question_type: "short_answer", created_at: Time.current)

    assert_equal [ q3.id, q2.id, q1.id ], category.questions.pluck(:id)
    assert_equal [ q3.id, q2.id, q1.id ], Question.where(id: [ q1.id, q2.id, q3.id ]).ordered.pluck(:id)
  end
end
