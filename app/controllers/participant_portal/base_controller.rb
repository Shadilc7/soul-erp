module ParticipantPortal
  class BaseController < ApplicationController
    before_action :authenticate_user!
    before_action :require_participant_access
    layout "participant"

    private

    def require_participant_access
      unless current_user&.participant? && current_user&.participant.present?
        redirect_to root_path,
          alert: "Access denied. Please contact your administrator."
      end
    end

    # Returns the student participant when a guardian has switched into student-view,
    # otherwise returns the logged-in user's own participant record.
    def current_participant
      if session[:viewing_student_id].present?
        own = current_user&.participant
        if own&.guardian?
          student = own.student_participants.find_by(id: session[:viewing_student_id].to_i)
          if student
            @current_participant = student
            return @current_participant
          else
            session.delete(:viewing_student_id)
          end
        else
          session.delete(:viewing_student_id)
        end
      end
      @current_participant ||= current_user&.participant
    end
    helper_method :current_participant

    # Always returns the logged-in user's own participant (never the viewed student).
    def own_participant
      @own_participant ||= current_user&.participant
    end
    helper_method :own_participant

    # True when a guardian is currently viewing a student's profile.
    def viewing_as_student?
      session[:viewing_student_id].present? &&
        current_user.participant&.guardian? &&
        current_user.participant.student_participants.exists?(id: session[:viewing_student_id].to_i)
    end
    helper_method :viewing_as_student?

    def current_institute
      @current_institute ||= current_user&.institute
    end
    helper_method :current_institute
  end
end
