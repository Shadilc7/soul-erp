require "test_helper"

class Admin::QuestionBanksControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @admin = users(:master_admin)
    sign_in @admin
    @bank = QuestionBank.create!(name: "General Knowledge Bank", description: "All general categories")
  end

  test "should get index" do
    get admin_question_banks_path
    assert_response :success
    assert_select "h1", text: /Question Banks/
    assert_includes response.body, @bank.name
  end

  test "should get new" do
    get new_admin_question_bank_path
    assert_response :success
  end

  test "should create question_bank" do
    assert_difference("QuestionBank.count", 1) do
      post admin_question_banks_path, params: {
        question_bank: {
          name: "Mathematics Bank",
          description: "Math category bank",
          active: true
        }
      }
    end

    assert_redirected_to admin_question_banks_path
    assert_equal "Question Bank 'Mathematics Bank' was successfully created.", flash[:notice]
  end

  test "should get edit" do
    get edit_admin_question_bank_path(@bank)
    assert_response :success
  end

  test "should update question_bank" do
    patch admin_question_bank_path(@bank), params: {
      question_bank: {
        name: "Updated GK Bank"
      }
    }

    assert_redirected_to admin_question_banks_path
    assert_equal "Updated GK Bank", @bank.reload.name
  end

  test "should destroy question_bank when not in use" do
    assert_difference("QuestionBank.count", -1) do
      delete admin_question_bank_path(@bank)
    end

    assert_redirected_to admin_question_banks_path
    assert_response :see_other
    assert_equal "Question Bank '#{@bank.name}' was deleted.", flash[:notice]
  end

  test "should not destroy question_bank when category is in use by assignments" do
    institute = Institute.first || Institute.create!(
      name: "Inst Test",
      code: "INST_T1",
      email: "t1@example.com",
      contact_number: "9876543210",
      institution_type: "college"
    )
    cat = QuestionCategory.create!(name: "In Use Category", duration_days: 10, question_bank: @bank, institute: nil)
    Assignment.create!(
      title: "Active Assignment",
      institute: institute,
      question_category: cat,
      start_date: Date.today,
      end_date: Date.today + 5.days,
      assignment_type: "individual"
    )

    assert_no_difference("QuestionBank.count") do
      delete admin_question_bank_path(@bank)
    end

    assert_redirected_to admin_question_banks_path
    assert_response :see_other
    assert_includes flash[:alert], "Cannot delete Question Bank"
  end
end
