require "test_helper"

class InstituteAdmin::ReportsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @admin = users(:one)
    @institute = @admin.institute
    
    # Create section
    @section = Section.create!(
      name: "Test Section",
      code: "TS01",
      capacity: 30,
      institute: @institute
    )
    
    # Update admin user section
    @admin.update!(section: @section)
    
    # Create participant user
    @participant_user = User.create!(
      email: "student@example.com",
      password: "password123",
      password_confirmation: "password123",
      role: :participant,
      first_name: "Test",
      last_name: "Student",
      institute: @institute,
      section: @section
    )
    
    # Create participant
    @participant = Participant.create!(
      user: @participant_user,
      institute: @institute,
      section_id: @section.id,
      date_of_birth: 15.years.ago.to_date
    )
    
    # Create training program
    @training_program = TrainingProgram.create!(
      title: "Test Program",
      description: "Test Program Description",
      institute: @institute,
      trainer: trainers(:one),
      program_type: :individual,
      participant: @participant,
      start_date: 1.month.ago.to_date,
      end_date: 1.month.from_now.to_date,
      status: :ongoing
    )
    
    # Add participant to training program
    TrainingProgramParticipant.create!(
      participant: @participant,
      training_program: @training_program
    )
    
    # Create feedback
    @feedback = TrainingProgramFeedback.create!(
      participant: @participant,
      training_program: @training_program,
      rating: 5,
      content: "Great training!"
    )
    
    sign_in @admin
  end

  test "should get individual feedback reports pdf successfully" do
    get individual_feedback_reports_institute_admin_reports_url(
      format: :pdf,
      submission_status: "submitted",
      date_range: "all",
      section_id: @section.id,
      participant_id: @participant.id,
      training_program_id: @training_program.id,
      commit: "Generate Report"
    )
    
    assert_response :success
    assert_equal "application/pdf", response.media_type
    assert response.body.start_with?("%PDF")
  end
end
