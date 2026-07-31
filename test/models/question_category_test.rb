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
end
