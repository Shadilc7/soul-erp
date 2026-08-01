require "test_helper"

class InstituteAdmin::AssignmentsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @admin = users(:one)
    @institute = @admin.institute
    sign_in @admin

    # Setup Question Bank with 2 categories and bundles
    @question_bank = QuestionBank.create!(
      name: "Core Tech Assessment Bank",
      description: "Master bank for tech evaluations",
      active: true
    )

    @category_a = QuestionCategory.create!(
      question_bank: @question_bank,
      name: "Ruby Fundamentals",
      description: "Basics of Ruby syntax & OOP",
      duration_days: 30,
      active: true
    )

    @category_b = QuestionCategory.create!(
      question_bank: @question_bank,
      name: "Advanced Rails Architecture",
      description: "Deep dive into Rails 8 & Postgres",
      duration_days: 45,
      active: true
    )

    # Setup bundles for Category A
    @bundle1 = QuestionBundle.create!(
      question_category: @category_a,
      name: "Part A - Basic Syntax",
      position: 1
    )

    @bundle2 = QuestionBundle.create!(
      question_category: @category_a,
      name: "Part B - OOP Concepts",
      position: 2
    )

    # Setup questions
    @q1 = Question.create!(
      title: "What is a Symbol?",
      question_type: "short_answer",
      question_category: @category_a
    )

    @q2 = Question.create!(
      title: "Explain Classes vs Modules",
      question_type: "paragraph",
      question_category: @category_a
    )

    @q3 = Question.create!(
      title: "What is garbage collection?",
      question_type: "paragraph",
      question_category: @category_a
    )

    # Associate questions with bundles
    QuestionBundleItem.create!(question_bundle: @bundle1, question: @q1, position: 1)
    QuestionBundleItem.create!(question_bundle: @bundle2, question: @q2, position: 1)
    # @q3 remains unbundled in @category_a
  end

  test "should import question bank and create category assignments with proper duration_days and bundled question ordering" do
    assert_difference("Assignment.count", 2) do
      post import_question_bank_institute_admin_assignments_path, params: { question_bank_id: @question_bank.id }
    end

    assert_redirected_to institute_admin_assignments_path
    assert_match /Successfully imported/, flash[:notice]

    # Verify Assignment A (Ruby Fundamentals)
    assignment_a = Assignment.find_by(title: "Ruby Fundamentals")
    assert_not_nil assignment_a
    assert_equal @category_a.id, assignment_a.question_category_id
    assert_equal Date.current, assignment_a.start_date.to_date
    assert_equal Date.current + 30.days, assignment_a.end_date.to_date

    # Verify Question ordering in Assignment A (Only Bundled Questions: Bundle 1 -> Bundle 2)
    ordered_q_ids = assignment_a.assignment_questions.order(:order_number).pluck(:question_id)
    assert_equal [@q1.id, @q2.id], ordered_q_ids

    # Verify Assignment B (Advanced Rails Architecture)
    assignment_b = Assignment.find_by(title: "Advanced Rails Architecture")
    assert_not_nil assignment_b
    assert_equal @category_b.id, assignment_b.question_category_id
    assert_equal Date.current, assignment_b.start_date.to_date
    assert_equal Date.current + 45.days, assignment_b.end_date.to_date
  end

  test "should import only selected categories when category_ids parameter is provided" do
    assert_difference("Assignment.count", 1) do
      post import_question_bank_institute_admin_assignments_path, params: {
        question_bank_id: @question_bank.id,
        category_ids: [@category_a.id]
      }
    end

    assert_redirected_to institute_admin_assignments_path
    assert_nil Assignment.find_by(title: "Advanced Rails Architecture")
    assert_not_nil Assignment.find_by(title: "Ruby Fundamentals")
  end

  test "should show assignment with bundle-grouped questions layout" do
    post import_question_bank_institute_admin_assignments_path, params: { question_bank_id: @question_bank.id }
    assignment = Assignment.find_by(title: "Ruby Fundamentals")

    get institute_admin_assignment_path(assignment)
    assert_response :success
    assert_select "h6", text: "Part A - Basic Syntax"
    assert_select "h6", text: "Part B - OOP Concepts"
  end

  test "should edit assignment with bundle-grouped questions selection form" do
    post import_question_bank_institute_admin_assignments_path, params: { question_bank_id: @question_bank.id }
    assignment = Assignment.find_by(title: "Ruby Fundamentals")

    get edit_institute_admin_assignment_path(assignment)
    assert_response :success
    assert_select "h6", text: "Part A - Basic Syntax"
    assert_select "h6", text: "Part B - OOP Concepts"
    assert_select "h5", text: /Participants/
    assert_select "input[type='submit'][value='Save Assignment Changes']"
  end

  test "should include institution custom questions in edit form and allow adding them to assignment" do
    inst_question = Question.create!(
      institute: @institute,
      title: "What is your employee code?",
      question_type: "short_answer"
    )

    post import_question_bank_institute_admin_assignments_path, params: { question_bank_id: @question_bank.id }
    assignment = Assignment.find_by(title: "Ruby Fundamentals")

    get edit_institute_admin_assignment_path(assignment)
    assert_response :success
    assert_select "h6", text: "Institution Custom Questions"

    participant = participants(:one)
    patch institute_admin_assignment_path(assignment), params: {
      assignment: {
        title: "Ruby Fundamentals (Updated)",
        start_date: assignment.start_date,
        end_date: assignment.end_date,
        assignment_type: "individual",
        participant_ids: [participant.id],
        question_ids: [@q1.id, inst_question.id]
      }
    }

    assert_redirected_to institute_admin_assignment_path(assignment)
    assignment.reload
    assert_includes assignment.question_ids, inst_question.id
  end
end
