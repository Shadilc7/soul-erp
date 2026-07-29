require "test_helper"

class Admin::QuestionCategoriesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @admin = users(:master_admin)
    sign_in @admin
    @category = QuestionCategory.create!(
      name: "Test Category",
      start_date: Date.current,
      end_date: Date.current + 30.days
    )
  end

  test "should get index" do
    get admin_question_categories_path
    assert_response :success
    assert_select "h2", text: /Master Question Bank/
  end

  test "should get builder" do
    get builder_admin_question_category_path(@category)
    assert_response :success
    assert_select "h2", text: @category.name
  end
end
