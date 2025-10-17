module ParticipantPortal
  class AssignmentResponsesController < ParticipantPortal::BaseController
    def create
      @assignment = current_institute.assignments.find(params[:assignment_id])
      @date = Date.parse(params[:date])

      # Process responses
      if params[:responses].present?
        params[:responses].each do |question_id, response_data|
          question = Question.find(question_id)

          # Handle different question types
          response_attributes = case question.question_type
          when "multiple_choice", "dropdown", "rating"
                            { answer: response_data[:answer] }
          when "checkboxes"
                            { selected_options: response_data[:selected_options]&.reject(&:blank?) }
          else
                            { answer: response_data[:answer] }
          end

          # Create or update response
          response = AssignmentResponse.find_or_initialize_by(
            assignment_id: @assignment.id,
            participant_id: current_participant.id,
            question_id: question_id,
            response_date: @date
          )

          response.update(response_attributes.merge(submitted_at: Time.current))
        end

        redirect_to participant_portal_assignments_path, notice: "Responses submitted successfully!"
      else
        redirect_to take_assignment_participant_portal_assignment_path(@assignment, date: @date),
                    alert: "No responses were submitted."
      end
    end
  end
end
