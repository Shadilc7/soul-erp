require "test_helper"

class QuestionCategoryTest < ActiveSupport::TestCase
  test "should be valid with name and duration_days" do
    cat = QuestionCategory.new(
      name: "Mathematics Q1",
      duration_days: 30
    )
    assert cat.valid?
  end

  test "should require name" do
    cat = QuestionCategory.new(duration_days: 10)
    assert_not cat.valid?
    assert_includes cat.errors[:name], "can't be blank"
  end

  test "duration_days must be positive" do
    cat = QuestionCategory.new(
      name: "Invalid Duration",
      duration_days: 0
    )
    assert_not cat.valid?
    assert_includes cat.errors[:duration_days], "must be greater than 0"
  end

  test "should prevent destroy if assigned to assignments" do
    cat = QuestionCategory.create!(name: "Test Cat", duration_days: 10)
    inst = Institute.first || Institute.create!(
      name: "Test Inst",
      code: "INST01",
      email: "inst@example.com",
      contact_number: "9876543210",
      institution_type: "college"
    )
    Assignment.create!(
      title: "Test Assignment for Destroy",
      institute: inst,
      question_category: cat,
      start_date: Date.today,
      end_date: Date.today + 5.days,
      assignment_type: "individual"
    )

    assert_no_difference "QuestionCategory.count" do
      refute cat.destroy
    end
    assert_includes cat.errors[:base].join, "Cannot delete Question Category"
  end
end
