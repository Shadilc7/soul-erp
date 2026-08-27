require "test_helper"

class QuestionBundleItemTest < ActiveSupport::TestCase
  setup do
    @category = QuestionCategory.create!(name: "Math Test Category", duration_days: 30)
    @bundle1 = @category.question_bundles.create!(name: "Part 1", from_day: 1, to_day: 7)
    @bundle2 = @category.question_bundles.create!(name: "Part 2", from_day: 8, to_day: 14)
  end

  test "calculates effective_from_day and effective_to_day on save" do
    question = @category.questions.create!(
      title: "Sample Question Day 1-10",
      question_type: "short_answer",
      from_day: 1,
      to_day: 10
    )

    item1 = QuestionBundleItem.create!(question_bundle: @bundle1, question: question)
    assert_equal 1, item1.effective_from_day
    assert_equal 7, item1.effective_to_day
    assert_equal 7, item1.days_in_bundle
    assert_equal "Day 1st - 7th Day", item1.effective_day_range_text

    question2 = @category.questions.create!(
      title: "Sample Question Day 8-10",
      question_type: "short_answer",
      from_day: 8,
      to_day: 10
    )
    item2 = QuestionBundleItem.create!(question_bundle: @bundle2, question: question2)
    assert_equal 8, item2.effective_from_day
    assert_equal 10, item2.effective_to_day
    assert_equal 3, item2.days_in_bundle
    assert_equal "Day 8th - 10th Day", item2.effective_day_range_text
  end

  test "prevents assigning question to bundle with non-overlapping day ranges" do
    question_out_of_range = @category.questions.create!(
      title: "Question Day 8-10",
      question_type: "short_answer",
      from_day: 8,
      to_day: 10
    )

    item = QuestionBundleItem.new(question_bundle: @bundle1, question: question_out_of_range)
    assert_not item.valid?
    assert_includes item.errors.full_messages.to_sentence, "does not overlap"
  end

  test "recalculates effective day range when assigned question range is updated" do
    question = @category.questions.create!(
      title: "Question Day 1-10",
      question_type: "short_answer",
      from_day: 1,
      to_day: 10
    )
    item = QuestionBundleItem.create!(question_bundle: @bundle1, question: question)
    assert_equal 1, item.effective_from_day
    assert_equal 7, item.effective_to_day

    # Edit question range to Day 5-10
    question.update!(from_day: 5, to_day: 10)
    item.reload
    assert_equal 5, item.effective_from_day
    assert_equal 7, item.effective_to_day
    assert_equal 3, item.days_in_bundle
  end

  test "removes bundle item if question range is updated to no longer overlap with bundle" do
    question = @category.questions.create!(
      title: "Question Day 1-10",
      question_type: "short_answer",
      from_day: 1,
      to_day: 10
    )
    item = QuestionBundleItem.create!(question_bundle: @bundle1, question: question)

    # Edit question range to Day 10-14 (Bundle 1 is Day 1-7, so no overlap!)
    question.update!(from_day: 10, to_day: 14)
    assert_not QuestionBundleItem.exists?(id: item.id)
  end

  test "automatically sets sequential position on create" do
    q1 = @category.questions.create!(title: "Q1", question_type: "short_answer", from_day: 1, to_day: 7)
    q2 = @category.questions.create!(title: "Q2", question_type: "short_answer", from_day: 1, to_day: 7)
    q3 = @category.questions.create!(title: "Q3", question_type: "short_answer", from_day: 1, to_day: 7)

    item1 = QuestionBundleItem.create!(question_bundle: @bundle1, question: q1)
    item2 = QuestionBundleItem.create!(question_bundle: @bundle1, question: q2)
    item3 = QuestionBundleItem.create!(question_bundle: @bundle1, question: q3)

    assert_equal 1, item1.position
    assert_equal 2, item2.position
    assert_equal 3, item3.position

    @bundle1.reload
    assert_equal [item1, item2, item3], @bundle1.question_bundle_items.to_a
    assert_equal [q1, q2, q3], @bundle1.questions.to_a
  end
end
