require "test_helper"

class Admin::QuestionCategoriesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @admin = users(:master_admin)
    sign_in @admin
    @bank = QuestionBank.create!(name: "Test Bank")
    @category = QuestionCategory.create!(
      question_bank: @bank,
      name: "Test Category",
      duration_days: 30
    )
  end

  test "should get index" do
    get admin_question_categories_path
    assert_response :success
    assert_select "h2", text: /Question Categories/
  end

  test "should get builder" do
    get builder_admin_question_category_path(@category)
    assert_response :success
    assert_select "h2", text: @category.name
  end

  test "auto_assign_bundles sets sequential positions and preserves order" do
    bundle = @category.question_bundles.create!(name: "Part 1", from_day: 1, to_day: 7)
    q1 = @category.questions.create!(title: "Q1", question_type: "short_answer", from_day: 1, to_day: 7)
    q2 = @category.questions.create!(title: "Q2", question_type: "short_answer", from_day: 1, to_day: 7)
    q3 = @category.questions.create!(title: "Q3", question_type: "short_answer", from_day: 1, to_day: 7)

    post auto_assign_bundles_admin_question_category_path(@category)
    assert_redirected_to builder_admin_question_category_path(@category)

    bundle.reload
    items = bundle.question_bundle_items.to_a
    assert_equal 3, items.size
    assert_equal [1, 2, 3], items.map(&:position)
    assert_equal [q1.id, q2.id, q3.id], items.map(&:question_id)

    # Reorder questions in bundle (swap q1 and q3)
    post reorder_questions_admin_question_category_bundle_path(@category, bundle), params: {
      question_ids: [q3.id, q2.id, q1.id]
    }, as: :json

    assert_response :success
    bundle.reload
    assert_equal [q3.id, q2.id, q1.id], bundle.question_bundle_items.pluck(:question_id)
    assert_equal [q3.id, q2.id, q1.id], bundle.questions.pluck(:id)
  end
end
