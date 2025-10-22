module InstituteAdmin
  class ResponsesController < InstituteAdmin::BaseController
    before_action :set_date, only: [ :index ]
    before_action :set_section, only: [ :index ], if: -> { params[:section_id].present? }
    before_action :set_participant, only: [ :index ], if: -> { params[:participant_id].present? && params[:section_id].present? }
    before_action :set_assignment, only: [ :index ], if: -> { params[:assignment_id].present? }

    def index
      # Always load sections
      @sections = current_institute.sections.active

      # Ensure participants are loaded for the section if it exists
      if @section
        @participants = @section.participants
                              .includes(:user)
                              .where(status: :active)
                              .where(participant_type: "student")
        Rails.logger.debug "Found #{@participants.count} participants for section #{@section.id}"
      end

      # Log form submission details
      if params[:commit].present?
        Rails.logger.debug "Form submitted with date: #{@selected_date}, section_id: #{params[:section_id]}, participant_id: #{params[:participant_id]}"
      end

      # Only proceed with fetching assignments if the form was submitted
      if params[:commit].present? && @participant && @start_date && @end_date
        @assignments = @participant.assignments_for_date_range(@start_date, @end_date)
        Rails.logger.debug "Found #{@assignments.count} assignments for participant #{@participant.id} from #{@start_date} to #{@end_date}"

        # If assignment_id is provided, fetch responses
        if @assignment
          @responses = @assignment.assignment_responses
            .where(participant: @participant)
            .where(response_date: @start_date..@end_date)
            .joins(:question)
            .order("assignment_responses.response_date DESC, questions.title")
            .page(params[:page]).per(20)

          # Let's log some debug info
          Rails.logger.debug "Date Range: #{@start_date} to #{@end_date}"
          Rails.logger.debug "Assignment ID: #{@assignment.id}"
          Rails.logger.debug "Participant ID: #{@participant.id}"
          Rails.logger.debug "Response Count: #{@responses.total_count}"
          Rails.logger.debug "Current Page: #{params[:page] || 1}"
        end
      end
    end

    def show
      @response = if @assignment
        @assignment.assignment_responses.find(params[:id])
      else
        AssignmentResponse.joins(:participant)
          .where(participants: { institute_id: current_institute.id })
          .find(params[:id])
      end
    end

    private

    def set_date
      date_filter = params[:date_filter] || "today"

      case date_filter
      when "today"
        @start_date = Date.current
        @end_date = Date.current
      when "yesterday"
        @start_date = Date.yesterday
        @end_date = Date.yesterday
      when "last_7_days"
        @start_date = 7.days.ago.to_date
        @end_date = Date.current
      when "last_month"
        @start_date = 1.month.ago.to_date
        @end_date = Date.current
      when "custom"
        if params[:start_date].present? && params[:end_date].present?
          @start_date = Date.parse(params[:start_date])
          @end_date = Date.parse(params[:end_date])
        else
          @start_date = Date.current
          @end_date = Date.current
        end
      else
        @start_date = Date.current
        @end_date = Date.current
      end

      # Keep backward compatibility with old @selected_date
      @selected_date = @start_date
      @date_filter = date_filter

    rescue ArgumentError
      @start_date = Date.current
      @end_date = Date.current
      @selected_date = Date.current
      @date_filter = "today"
    end

    def set_section
      @section = current_institute.sections.find(params[:section_id])
    end

    def set_participant
      begin
        @participant = @section.participants.find(params[:participant_id])
      rescue ActiveRecord::RecordNotFound
        flash.now[:alert] = "Participant not found."
        @participant = nil
      end
    end

    def set_assignment
      begin
        @assignment = Assignment.find(params[:assignment_id])
      rescue ActiveRecord::RecordNotFound
        flash.now[:alert] = "Assignment not found."
        @assignment = nil
      end
    end
  end
end
