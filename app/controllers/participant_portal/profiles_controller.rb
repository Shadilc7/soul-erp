module ParticipantPortal
  class ProfilesController < ParticipantPortal::BaseController
    def show
      @participant = current_participant
      @training_programs = @participant.all_training_programs.includes(trainer: :user)
    end

    def student_info
      @participant = current_participant
      unless @participant.guardian?
        redirect_to participant_portal_profile_path,
          alert: "This page is only accessible to guardians."
        return
      end

      @student = @participant.student_participants.includes(:user, :section).find_by(id: params[:student_id])
      unless @student
        redirect_to participant_portal_profile_path,
          alert: "Student not found."
      end
    end
  end
end
