module ParticipantPortal
  class StudentViewsController < ParticipantPortal::BaseController
    before_action :ensure_guardian

    # POST /participant_portal/student_view/:student_id
    def switch
      student = own_participant.student_participants.find_by(id: params[:student_id])
      if student
        session[:viewing_student_id] = student.id
        redirect_to participant_portal_root_path,
          notice: "Now viewing #{student.user.full_name}'s profile."
      else
        redirect_to participant_portal_root_path, alert: "Student not found."
      end
    end

    # DELETE /participant_portal/student_view
    def return_to_guardian
      session.delete(:viewing_student_id)
      redirect_to participant_portal_root_path,
        notice: "Returned to your own profile."
    end

    private

    def ensure_guardian
      unless own_participant&.guardian?
        redirect_to participant_portal_root_path, alert: "Access denied."
      end
    end
  end
end
