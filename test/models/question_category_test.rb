require "test_helper"

class QuestionCategoryTest < ActiveSupport::TestCase
  test "should be valid with name, start_date and end_date" do
    cat = QuestionCategory.new(
      name: "Mathematics Q1",
      start_date: Date.current,
      end_date: Date.current + 30.days
    )
    assert cat.valid?
  end

  test "should require name" do
    cat = QuestionCategory.new(start_date: Date.current, end_date: Date.current + 10.days)
    assert_not cat.valid?
    assert_includes cat.errors[:name], "can't be blank"
  end

  test "end date cannot be before start date" do
    cat = QuestionCategory.new(
      name: "Invalid Dates",
      start_date: Date.current,
      end_date: Date.current - 5.days
    )
    assert_not cat.valid?
    assert_includes cat.errors[:end_date], "must be after or equal to the start date"
  end
end
