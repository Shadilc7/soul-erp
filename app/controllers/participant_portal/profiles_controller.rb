module ParticipantPortal
  class ProfilesController < ParticipantPortal::BaseController
    def show
      @participant = current_participant
    end

    def student_info
      @participant = current_participant
      unless @participant.guardian?
        redirect_to participant_portal_profile_path,
          alert: "This page is only accessible to guardians."
        return
      end

      @student = @participant.guardian_for_participant
      unless @student
        redirect_to participant_portal_profile_path,
          alert: "No student information found."
      end
    end
  end
end
