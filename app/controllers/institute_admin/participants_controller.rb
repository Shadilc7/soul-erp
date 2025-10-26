require "csv"
require "securerandom"

module InstituteAdmin
  class ParticipantsController < InstituteAdmin::BaseController
    before_action :set_participant, only: [ :show, :edit, :update, :destroy, :toggle_status ]
    before_action :set_sections, only: [ :new, :create, :edit, :update ]

    def index
      @participants = current_institute.participants.includes(:user, :section).order(created_at: :desc)

      # Filter by approval status
      if params[:approved] == "false"
        @participants = @participants.joins(:user).where(users: { active: false })
        @approval_status = "not_approved"
      else
        # Default is to show approved participants
        @participants = @participants.joins(:user).where(users: { active: true })
        @approval_status = "approved"
      end

      # Add pagination
      @participants = @participants.page(params[:page]).per(20)
    end

    def show
      @user = @participant.user
      @guardian = @participant.guardian
    end

    def new
      @user = User.new
      @user.build_participant
    end

    def create
      @user = User.new(user_params)
      @user.institute = current_institute
      @user.role = :participant
      @user.phone = user_params[:participant_attributes][:phone_number]

      # Set institute for participant
      @user.participant.institute = current_institute if @user.participant

      # Set section ID for students and employees
      if params[:user][:participant_attributes][:participant_type].in?([ "student", "employee" ])
        @user.section_id = params[:user][:participant_attributes][:section_id]
      end

      # For guardians, set section ID based on the selected student's section
      if params[:user][:participant_attributes][:participant_type] == "guardian" &&
         params[:user][:participant_attributes][:guardian_for_participant_id].present?
        student = Participant.find(params[:user][:participant_attributes][:guardian_for_participant_id])
        @user.section_id = student.section_id if student.present?
      end

      if @user.save
        redirect_to institute_admin_participants_path, notice: "Participant was successfully created."
      else
        set_sections
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @user = @participant.user

      # Ensure institute is set for participant
      @participant.institute = current_institute

      # Ensure participant attributes are properly loaded
      if @participant.guardian? && @participant.guardian_for_participant.nil? && @participant.guardian_for_participant_id.present?
        # Try to load the guardian_for_participant if it exists but isn't loaded
        @participant.guardian_for_participant = Participant.find_by(id: @participant.guardian_for_participant_id)

        # If we found the associated student, also load their section
        if @participant.guardian_for_participant
          @participant.guardian_for_participant.section = Section.find_by(id: @participant.guardian_for_participant.section_id)
        end
      end
    end

    def update
      @user = User.find(params[:id])
      @participant = @user.participant

      # Ensure institute is set for participant
      @participant.institute = current_institute if @participant

      # Set section ID for students and employees
      if params[:user][:participant_attributes][:participant_type].in?([ "student", "employee" ])
        @user.section_id = params[:user][:participant_attributes][:section_id]
      end

      # For guardians, set section ID based on the selected student's section
      if params[:user][:participant_attributes][:participant_type] == "guardian" &&
         params[:user][:participant_attributes][:guardian_for_participant_id].present?
        student = Participant.find(params[:user][:participant_attributes][:guardian_for_participant_id])
        @user.section_id = student.section_id if student.present?
      end

      if @user.update(user_params)
        redirect_to "#{institute_admin_participants_path}/?approved=#{@user.active}", notice: "Participant was successfully updated."
      else
        set_sections
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      begin
        if @user.destroy
          redirect_to institute_admin_participants_path,
            notice: "Participant was successfully deleted."
        else
          redirect_to institute_admin_participants_path,
            alert: "Failed to delete participant: #{@user.errors.full_messages.to_sentence}"
        end
      rescue ActiveRecord::InvalidForeignKey => e
        redirect_to institute_admin_participants_path,
          alert: "Cannot delete participant because it is referenced by other records. Please remove those associations first."
      rescue StandardError => e
        redirect_to institute_admin_participants_path,
          alert: "An error occurred: #{e.message}"
      end
    end

    def assignments
      @participant = current_institute.participants.find(params[:id])

      # Get assignments for this participant (both individual and section assignments)
      individual_assignments = Assignment.joins(:assignment_participants)
                                        .where(assignment_participants: { participant_id: @participant.id })

      section_assignments = Assignment.joins(:assignment_sections)
                                     .where(assignment_sections: { section_id: @participant.section_id })

      @assignments = Assignment.where(id: individual_assignments.pluck(:id) + section_assignments.pluck(:id))
                              .distinct.order(created_at: :desc)

      respond_to do |format|
        format.json { render json: @assignments.map { |a| { id: a.id, title: a.title } } }
      end
    end

    def toggle_status
      @user = User.find(params[:id])
      # Toggle the active status
      @user.active = !@user.active

      if @user.save
        status_message = @user.active? ? "approved" : "unapproved"
        redirect_back fallback_location: institute_admin_participants_path,
          notice: "Participant was successfully #{status_message}."
      else
        redirect_back fallback_location: institute_admin_participants_path,
          alert: "Failed to update participant status: #{@user.errors.full_messages.to_sentence}"
      end
    end

    def approve_all
      # Get all not approved participants for the current institute
      not_approved_users = current_institute.users
                          .where(role: :participant, active: false)
                          .joins(:participant)

      # Approve all participants
      count = 0
      not_approved_users.find_each do |user|
        user.active = true
        count += 1 if user.save
      end

      if count > 0
        redirect_to institute_admin_participants_path(approved: true),
          notice: "Successfully approved #{count} participant#{count > 1 ? 's' : ''}."
      else
        redirect_to institute_admin_participants_path(approved: false),
          alert: "No participants were approved."
      end
    end

    private

    def set_participant
      # Try to find the participant directly through the institute's participants
      @participant = current_institute.participants.find_by(id: params[:id])

      # If not found, try to find through the user
      if @participant.nil?
        @user = current_institute.users.find_by(id: params[:id])
        @participant = @user&.participant
      else
        @user = @participant.user
      end

      # Raise RecordNotFound if neither approach found a participant
      raise ActiveRecord::RecordNotFound unless @participant && @user
    end

    def set_sections
      @sections = current_institute.sections.active
    end

    def user_params
      params.require(:user).permit(
        :first_name,
        :last_name,
        :email,
        :password,
        :password_confirmation,
        :section_id,
        participant_attributes: [
          :id,
          :date_of_birth,
          :phone_number,
          :section_id,
          :status,
          :institute_id,
          :participant_type,
          :job_role,
          :qualification,
          :years_of_experience,
          :enrollment_date,
          :guardian_for_participant_id,
          :address,
          :pin_code,
          :district,
          :state
        ]
      )
    end
  end
end
