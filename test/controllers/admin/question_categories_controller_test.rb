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
end
