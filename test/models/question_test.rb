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

  test "new Option initializes with nil text instead of pre-filled dummy value" do
    opt = Option.new
    assert_nil opt.text
    assert_nil opt.value
  end

  test "multiple choice question validates presence of at least 2 options" do
    category = QuestionCategory.create!(name: "MC Category", duration_days: 30)
    q = category.questions.build(
      title: "Multiple Choice Q",
      question_type: "multiple_choice"
    )
    assert_not q.valid?
    assert_includes q.errors[:base], "Questions requiring options must have at least 2 options"

    q.options.build(text: "Choice A")
    q.options.build(text: "Choice B")
    assert q.valid?
  end

  test "allows destroy of master question even if attached to assignment questions" do
    inst = Institute.first || Institute.create!(
      name: "Test Inst",
      code: "INST02",
      email: "inst2@example.com",
      contact_number: "9876543210",
      institution_type: "college"
    )
    master_cat = QuestionCategory.create!(name: "Master Cat Q", duration_days: 10, institute: nil)
    master_q = master_cat.questions.create!(title: "Master Q", question_type: "short_answer", institute: nil)
    assignment = Assignment.create!(
      title: "Test Assignment for Master Q",
      institute: inst,
      start_date: Date.today,
      end_date: Date.today + 5.days,
      assignment_type: "individual"
    )
    aq = assignment.assignment_questions.create!(question: master_q, order_number: 1)

    assert master_q.destroy
    assert_not AssignmentQuestion.exists?(id: aq.id)
  end

  test "blocks destroy of institute question when attached to assignments" do
    inst = Institute.first || Institute.create!(
      name: "Test Inst",
      code: "INST03",
      email: "inst3@example.com",
      contact_number: "9876543210",
      institution_type: "college"
    )
    inst_cat = QuestionCategory.create!(name: "Inst Cat Q", duration_days: 10, institute: inst)
    inst_q = inst_cat.questions.create!(title: "Inst Q", question_type: "short_answer", institute: inst)
    assignment = Assignment.create!(
      title: "Test Assignment for Inst Q",
      institute: inst,
      start_date: Date.today,
      end_date: Date.today + 5.days,
      assignment_type: "individual"
    )
    assignment.assignment_questions.create!(question: inst_q, order_number: 1)

    assert_no_difference "Question.count" do
      refute inst_q.destroy
    end
    assert_includes inst_q.errors[:base].join, "This question cannot be deleted because it is being used in"
  end
end
