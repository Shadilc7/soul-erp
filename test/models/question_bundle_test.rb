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

  test "validates bundle day range within category ceiling" do
    valid_bundle = @category.question_bundles.build(name: "Part 1", from_day: 1, to_day: 15)
    assert valid_bundle.valid?

    exceeds_ceiling_bundle = @category.question_bundles.build(name: "Part 2", from_day: 1, to_day: 40)
    assert_not exceeds_ceiling_bundle.valid?
    assert_includes exceeds_ceiling_bundle.errors[:to_day], "cannot exceed category maximum duration of 30 days"

    invalid_range_bundle = @category.question_bundles.build(name: "Part 3", from_day: 20, to_day: 10)
    assert_not invalid_range_bundle.valid?
    assert_includes invalid_range_bundle.errors[:to_day], "must be greater than or equal to From Day (20)"
  end

  test "prevents overlapping bundle day ranges within same category" do
    @category.question_bundles.create!(name: "Bundle 1", from_day: 1, to_day: 10)

    # Overlapping bundle 1..5
    overlap_bundle = @category.question_bundles.build(name: "Bundle 2", from_day: 5, to_day: 15)
    assert_not overlap_bundle.valid?
    assert_includes overlap_bundle.errors[:base].join, "overlaps with existing bundle 'Bundle 1'"

    # Non-overlapping bundle 11..20
    valid_bundle = @category.question_bundles.build(name: "Bundle 3", from_day: 11, to_day: 20)
    assert valid_bundle.valid?
  end

  test "allows updating existing bundle without self-overlap conflict" do
    bundle = @category.question_bundles.create!(name: "Bundle 1", from_day: 1, to_day: 10)
    bundle.name = "Bundle 1 Updated"
    assert bundle.valid?
  end
end
