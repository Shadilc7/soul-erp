require "test_helper"

class QuestionBundleTest < ActiveSupport::TestCase
  setup do
    @category = QuestionCategory.create!(
      name: "Master Test Category",
      duration_days: 30
    )
  end

  test "should be valid with name" do
    bundle = @category.question_bundles.build(name: "Part 1")
    assert bundle.valid?
  end

  test "should allow adding questions to bundle" do
    bundle = @category.question_bundles.create!(name: "Part 1")
    question = @category.questions.create!(
      title: "Sample Question 1",
      question_type: "short_answer",
      duration_days: 1
    )

    bundle.questions << question
    assert_equal 1, bundle.questions.count
    assert_includes question.question_bundles, bundle
  end
end
