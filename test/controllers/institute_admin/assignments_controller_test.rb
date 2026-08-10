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
      from_day: 1,
      to_day: 15,
      position: 1
    )

    @bundle2 = QuestionBundle.create!(
      question_category: @category_a,
      name: "Part B - OOP Concepts",
      from_day: 16,
      to_day: 30,
      position: 2
    )

    # Setup questions
    @q1 = Question.create!(
      title: "What is a Symbol?",
      question_type: "short_answer",
      question_category: @category_a
    )

    @q2 = Question.create!(
      title: "Explain duck typing in Ruby",
      question_type: "paragraph",
      question_category: @category_a,
      from_day: 16,
      to_day: 30
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

  test "should render import_setup page with selected categories and participants" do
    get import_setup_institute_admin_assignments_path, params: {
      question_bank_id: @question_bank.id,
      category_ids: [@category_a.id, @category_b.id]
    }

    assert_response :success
    assert_select "h3", text: "Question Bank Import & Assignment Setup"
    assert_select "input[name='assignments[#{@category_a.id}][title]'][value='Ruby Fundamentals']"
    assert_select "input[name='assignments[#{@category_b.id}][title]'][value='Advanced Rails Architecture']"
  end

  test "should finalize_import and create customized batch assignments with assigned participants" do
    participant = participants(:one)

    assert_difference("Assignment.count", 2) do
      post finalize_import_institute_admin_assignments_path, params: {
        assignments: {
          @category_a.id => {
            title: "Ruby Fundamentals - Cohort 1",
            description: "Custom description for Cohort 1",
            start_date: Date.current.to_s,
            end_date: (Date.current + 30.days).to_s,
            assignment_type: "individual",
            active: "1",
            participant_ids: [participant.id],
            question_ids: [@q1.id, @q2.id]
          },
          @category_b.id => {
            title: "Advanced Rails Architecture - Cohort 1",
            description: "Deep dive for Cohort 1",
            start_date: Date.current.to_s,
            end_date: (Date.current + 45.days).to_s,
            assignment_type: "individual",
            active: "1",
            participant_ids: [participant.id]
          }
        }
      }
    end

    assert_redirected_to institute_admin_assignments_path
    assert_match /Successfully created 2 assignment/, flash[:notice]

    assign_a = Assignment.find_by(title: "Ruby Fundamentals - Cohort 1")
    assert_not_nil assign_a
    assert_equal "Custom description for Cohort 1", assign_a.description
    assert_includes assign_a.participant_ids, participant.id
    assert_equal [@q1.id, @q2.id], assign_a.assignment_questions.order(:order_number).pluck(:question_id)

    assign_b = Assignment.find_by(title: "Advanced Rails Architecture - Cohort 1")
    assert_not_nil assign_b
    assert_includes assign_b.participant_ids, participant.id
  end

  test "should filter questions when specific question_ids are selected during finalize_import" do
    assert_difference("Assignment.count", 1) do
      post finalize_import_institute_admin_assignments_path, params: {
        assignments: {
          @category_a.id => {
            title: "Ruby Fundamentals - Filtered",
            start_date: Date.current.to_s,
            end_date: (Date.current + 30.days).to_s,
            question_ids: ["", @q1.id.to_s] # Only @q1 included, @q2 excluded
          }
        }
      }
    end

    assign = Assignment.find_by(title: "Ruby Fundamentals - Filtered")
    assert_not_nil assign
    assert_equal [@q1.id], assign.assignment_questions.pluck(:question_id)
  end

  test "should redirect import_question_bank request to import_setup page" do
    post import_question_bank_institute_admin_assignments_path, params: { question_bank_id: @question_bank.id }
    assert_redirected_to import_setup_institute_admin_assignments_path(question_bank_id: @question_bank.id, category_ids: nil)
  end

  test "should show assignment with bundle-grouped questions layout" do
    post finalize_import_institute_admin_assignments_path, params: {
      assignments: {
        @category_a.id => { title: "Ruby Fundamentals", start_date: Date.current.to_s, end_date: (Date.current + 30.days).to_s }
      }
    }
    assignment = Assignment.find_by(title: "Ruby Fundamentals")

    get institute_admin_assignment_path(assignment)
    assert_response :success
    assert_select "h6", text: "Part A - Basic Syntax"
    assert_select "h6", text: "Part B - OOP Concepts"
  end

  test "should edit assignment with bundle-grouped questions selection form" do
    post finalize_import_institute_admin_assignments_path, params: {
      assignments: {
        @category_a.id => { title: "Ruby Fundamentals", start_date: Date.current.to_s, end_date: (Date.current + 30.days).to_s }
      }
    }
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

    post finalize_import_institute_admin_assignments_path, params: {
      assignments: {
        @category_a.id => { title: "Ruby Fundamentals", start_date: Date.current.to_s, end_date: (Date.current + 30.days).to_s }
      }
    }
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
