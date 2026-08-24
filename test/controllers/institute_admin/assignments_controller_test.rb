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

    # Setup master questions
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
    assert_equal ["What is a Symbol?", "Explain duck typing in Ruby"], assign_a.questions.order("assignment_questions.order_number").pluck(:title)
    assert_equal [@institute.id, @institute.id], assign_a.questions.pluck(:institute_id)
    assert_equal @institute.id, assign_a.question_category.institute_id
    assert_nil assign_a.question_category.question_bank_id

    assign_b = Assignment.find_by(title: "Advanced Rails Architecture - Cohort 1")
    assert_not_nil assign_b
    assert_includes assign_b.participant_ids, participant.id
    assert_equal @institute.id, assign_b.question_category.institute_id
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
    assert_equal ["What is a Symbol?"], assign.questions.pluck(:title)
    assert_equal [@institute.id], assign.questions.pluck(:institute_id)
  end

  test "should respect institution-specific bundle name overrides during finalize_import" do
    assert_difference("Assignment.count", 1) do
      post finalize_import_institute_admin_assignments_path, params: {
        assignments: {
          @category_a.id => {
            title: "Ruby Fundamentals - Custom Bundles",
            start_date: Date.current.to_s,
            end_date: (Date.current + 30.days).to_s,
            bundles: {
              @bundle1.id.to_s => {
                name: "Custom Part 1 - Basic Syntax Override",
                from_day: "1",
                to_day: "15",
                description: "Custom bundle description"
              }
            },
            question_ids: [@q1.id]
          }
        }
      }
    end

    assign = Assignment.find_by(title: "Ruby Fundamentals - Custom Bundles")
    assert_not_nil assign
    aq = assign.assignment_questions.first
    assert_not_nil aq
    assert_equal "Custom Part 1 - Basic Syntax Override", aq.bundle_name
    assert_equal @institute.id, aq.question.institute_id
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
    cloned_q1 = assignment.questions.find_by(title: @q1.title)

    patch institute_admin_assignment_path(assignment), params: {
      assignment: {
        title: "Ruby Fundamentals (Updated)",
        start_date: assignment.start_date,
        end_date: assignment.end_date,
        assignment_type: "individual",
        participant_ids: [participant.id],
        question_ids: [cloned_q1.id, inst_question.id]
      }
    }

    assert_redirected_to institute_admin_assignment_path(assignment)
    assignment.reload
    assert_includes assignment.question_ids, inst_question.id
  end

  test "should isolate imported assignment entities from master question bank modifications" do
    post finalize_import_institute_admin_assignments_path, params: {
      assignments: {
        @category_a.id => { title: "Ruby Fundamentals Independent", start_date: Date.current.to_s, end_date: (Date.current + 30.days).to_s }
      }
    }
    assignment = Assignment.find_by(title: "Ruby Fundamentals Independent")
    assert_not_nil assignment

    cloned_q = assignment.questions.find_by(title: @q1.title)
    assert_not_nil cloned_q
    assert_not_equal @q1.id, cloned_q.id
    assert_equal @institute.id, cloned_q.institute_id

    # Modify master question
    @q1.update!(title: "MODIFIED MASTER TITLE")

    # Assert imported assignment question title remains unchanged
    cloned_q.reload
    assert_equal "What is a Symbol?", cloned_q.title
  end

  test "should save questions assigned across multiple bundles when editing assignment" do
    post finalize_import_institute_admin_assignments_path, params: {
      assignments: {
        @category_a.id => { title: "Ruby Multi-Bundle Test", start_date: Date.current.to_s, end_date: (Date.current + 30.days).to_s }
      }
    }
    assignment = Assignment.find_by(title: "Ruby Multi-Bundle Test")
    assert_not_nil assignment

    cloned_q1 = assignment.questions.find_by(title: @q1.title)
    participant = participants(:one)

    patch institute_admin_assignment_path(assignment), params: {
      assignment: {
        title: "Ruby Multi-Bundle Test (Updated)",
        start_date: assignment.start_date,
        end_date: assignment.end_date,
        assignment_type: "individual",
        participant_ids: [participant.id],
        question_bundle_items: [
          { question_id: cloned_q1.id, bundle_name: "Part1" },
          { question_id: cloned_q1.id, bundle_name: "Part2" }
        ]
      }
    }

    assert_redirected_to institute_admin_assignment_path(assignment)
    assignment.reload

    grouped = assignment.questions_grouped_by_bundle
    assert_includes grouped.keys, "Part1"
    assert_includes grouped.keys, "Part2"
    assert_equal [cloned_q1.id], grouped["Part1"].map(&:id)
    assert_equal [cloned_q1.id], grouped["Part2"].map(&:id)
  end

  test "should update master question via JSON by cloning for current institute" do
    patch institute_admin_question_path(@q1, format: :json), params: {
      question: {
        title: "Updated Master Question Title",
        question_type: "multiple_choice",
        from_day: 1,
        to_day: 15,
        options_attributes: [
          { text: "Option A" },
          { text: "Option B" }
        ]
      }
    }

    assert_response :success
    json_response = JSON.parse(response.body)
    assert_equal "success", json_response["status"]
    assert_equal "Updated Master Question Title", json_response.dig("question", "title")
    assert_equal @institute.id, json_response.dig("question", "institute_id")
  end

  test "edit assignment view renders question pool edit button and excludes edit button inside bundle items" do
    post finalize_import_institute_admin_assignments_path, params: {
      assignments: {
        @category_a.id => { title: "UI Test Assignment", start_date: Date.current.to_s, end_date: (Date.current + 30.days).to_s }
      }
    }
    assignment = Assignment.find_by(title: "UI Test Assignment")

    get edit_institute_admin_assignment_path(assignment)
    assert_response :success

    # Edit Question pencil button in question pool exists
    assert_select "button[onclick*='openFormEditQuestionModal']"

    # In bundle items container, ensure pencil edit button is not present inside bundle item action group
    # Bundle item container id contains form_bundle_items_
    assert_select ".form-bundle-items-container" do
      assert_select "button[title='Edit Question']", count: 0
    end
  end

  test "should list participants in alphabetical order in new assignment page" do
    # Create users with out-of-order names for the current institute
    section = Section.create!(name: "Batch A", code: "BA1", capacity: 30, institute: @institute)
    u_z = User.create!(first_name: "Zara", last_name: "Alvarez", email: "zara@example.com", password: "Password123!", institute: @institute)
    Participant.create!(user: u_z, institute: @institute, section_id: section.id, date_of_birth: 20.years.ago, participant_type: :student)

    u_a = User.create!(first_name: "Aaron", last_name: "Smith", email: "aaron@example.com", password: "Password123!", institute: @institute)
    Participant.create!(user: u_a, institute: @institute, section_id: section.id, date_of_birth: 20.years.ago, participant_type: :student)

    u_m = User.create!(first_name: "Maya", last_name: "Lin", email: "maya@example.com", password: "Password123!", institute: @institute)
    Participant.create!(user: u_m, institute: @institute, section_id: section.id, date_of_birth: 20.years.ago, participant_type: :student)

    get new_institute_admin_assignment_path, params: { mode: 'custom' }
    assert_response :success

    aaron_pos = response.body.index("Aaron Smith")
    maya_pos = response.body.index("Maya Lin")
    zara_pos = response.body.index("Zara Alvarez")

    assert aaron_pos, "Aaron Smith should be in response"
    assert maya_pos, "Maya Lin should be in response"
    assert zara_pos, "Zara Alvarez should be in response"
    assert aaron_pos < maya_pos, "Aaron should appear before Maya"
    assert maya_pos < zara_pos, "Maya should appear before Zara"
  end

  test "should list participants in alphabetical order in import_setup page" do
    section = Section.create!(name: "Batch A", code: "BA2", capacity: 30, institute: @institute)
    u_z = User.create!(first_name: "Zara", last_name: "Alvarez", email: "zara2@example.com", password: "Password123!", institute: @institute)
    Participant.create!(user: u_z, institute: @institute, section_id: section.id, date_of_birth: 20.years.ago, participant_type: :student)

    u_a = User.create!(first_name: "Aaron", last_name: "Smith", email: "aaron2@example.com", password: "Password123!", institute: @institute)
    Participant.create!(user: u_a, institute: @institute, section_id: section.id, date_of_birth: 20.years.ago, participant_type: :student)

    get import_setup_institute_admin_assignments_path, params: {
      question_bank_id: @question_bank.id,
      category_ids: [@category_a.id]
    }
    assert_response :success

    aaron_pos = response.body.index("Aaron Smith")
    zara_pos = response.body.index("Zara Alvarez")

    assert aaron_pos, "Aaron Smith should be in response"
    assert zara_pos, "Zara Alvarez should be in response"
    assert aaron_pos < zara_pos, "Aaron should appear before Zara in import_setup"
  end
end
