module ParticipantPortal
  class AssignmentsController < ParticipantPortal::BaseController
    before_action :set_assignment, except: [ :index ]
    before_action :check_date_availability, only: [ :take_assignment, :submit ]

    def index
      @selected_date = parse_date(params[:date])

      # Direct SQL approach for PostgreSQL compatibility
      # This avoids the DISTINCT issues by explicitly selecting all columns we need to order by
      base_sql = <<-SQL
        SELECT DISTINCT ON (assignments.id) assignments.*
        FROM assignments
        LEFT JOIN assignment_participants ON assignments.id = assignment_participants.assignment_id
        LEFT JOIN assignment_sections ON assignments.id = assignment_sections.assignment_id
        WHERE assignments.active = true
        AND (assignment_participants.participant_id = :participant_id OR assignment_sections.section_id = :section_id)
      SQL

      base_params = {
        participant_id: current_participant.id,
        section_id: current_participant.section_id
      }

      # Today's assignments
      today_sql = base_sql + " AND DATE(assignments.start_date) <= :today AND DATE(assignments.end_date) >= :today ORDER BY assignments.id, assignments.created_at DESC"
      @today_assignments = Assignment.find_by_sql([ today_sql, base_params.merge(today: Date.current) ])

      # IDs of today's assignments to exclude from upcoming
      today_ids = @today_assignments.map(&:id)

      # Upcoming assignments
      upcoming_sql = base_sql + " AND DATE(assignments.end_date) >= :today AND assignments.id NOT IN (:today_ids) ORDER BY assignments.id, assignments.start_date ASC"
      upcoming_params = base_params.merge(today: Date.current, today_ids: today_ids.empty? ? [ 0 ] : today_ids)
      @upcoming_assignments = Assignment.find_by_sql([ upcoming_sql, upcoming_params ])

      # Past assignments
      past_sql = base_sql + " AND DATE(assignments.end_date) < :today ORDER BY assignments.id, assignments.end_date DESC"
      @past_assignments = Assignment.find_by_sql([ past_sql, base_params.merge(today: Date.current) ])

      # For the date selection in the view
      date_sql = base_sql + " AND DATE(assignments.start_date) <= :selected_date AND DATE(assignments.end_date) >= :selected_date ORDER BY assignments.id, assignments.created_at DESC"
      date_assignments = Assignment.find_by_sql([ date_sql, base_params.merge(selected_date: @selected_date) ])

      # Also create a regular relation for all assignments
      @assignments = Assignment.select("assignments.*")
                               .active
                               .joins("LEFT JOIN assignment_participants ON assignments.id = assignment_participants.assignment_id")
                               .joins("LEFT JOIN assignment_sections ON assignments.id = assignment_sections.assignment_id")
                               .where("assignment_participants.participant_id = :participant_id OR assignment_sections.section_id = :section_id",
                                 participant_id: current_participant.id,
                                 section_id: current_participant.section_id)
                               .distinct

      respond_to do |format|
        format.html # Will render index.html.erb template
        format.turbo_stream {
          render turbo_stream: turbo_stream.update("assignment_content",
            partial: "participant_portal/dashboard/daily_assignments",
            locals: {
              assignments: date_assignments,
              selected_date: @selected_date
            }
          )
        }
      end
    end

    def show
      @selected_date = params[:date].present? ? Date.parse(params[:date]) : Date.current

      @individual_questions = @assignment.questions.order(:created_at)
      @question_set_questions = @assignment.question_sets.includes(:questions)
        .flat_map(&:questions)

      respond_to do |format|
        format.html # renders show.html.erb
        format.turbo_stream {
          render turbo_stream: turbo_stream.update("main_content",
            template: "participant_portal/assignments/show"
          )
        }
      end
    end

    def take_assignment
      @selected_date = parse_date(params[:date])
      @questions = @assignment.all_questions
    end

    def submit
      @selected_date = parse_date(params[:date])
      @responses = params[:responses].to_unsafe_h

      # First check if already submitted
      if @assignment.answered_by_on_date?(current_participant, @selected_date)
        flash[:alert] = "You have already submitted this assignment for #{@selected_date.strftime('%B %d, %Y')}"
        redirect_to participant_portal_root_path
        return
      end

      begin
        ActiveRecord::Base.transaction do
          all_saved = true
          saved_response_ids = []

          @responses.each do |question_id, response_data|
            question = Question.find(question_id)
            response = current_participant.assignment_responses.find_or_initialize_by(
              assignment: @assignment,
              question_id: question_id,
              response_date: @selected_date
            )

            # Handle different question types
            case question.question_type
            when "checkboxes"
              response.selected_options = response_data[:selected_options].presence || []
              response.answer = response.selected_options.join(", ")
            when "multiple_choice", "dropdown", "rating"
              response.answer = response_data[:answer]
              response.selected_options = [ response_data[:answer] ].compact
            when "short_answer", "paragraph", "number", "date", "time"
              response.answer = response_data[:answer]
              response.selected_options = []
            else
              # Default handling for any other question types
              response.answer = response_data[:answer]
              response.selected_options = response_data[:selected_options].presence || []
            end

            response.submitted_at = Time.current

            if response.save
              saved_response_ids << response.id
            else
              Rails.logger.error("Failed to save response: #{response.errors.full_messages.join(', ')}")
              all_saved = false
              break
            end
          end

          if all_saved
            AssignmentResponseLog.log_responses(
              participant: current_participant,
              assignment: @assignment,
              response_ids: saved_response_ids,
              response_date: @selected_date
            )

            redirect_to participant_portal_root_path(date: @selected_date),
                        notice: "Assignment submitted successfully!"
          else
            raise ActiveRecord::Rollback
          end
        end
      rescue ActiveRecord::RecordNotUnique => e
        # Likely caused by a concurrent submission; handle gracefully and inform the user
        Rails.logger.warn("Unique constraint violation when saving assignment responses: #{e.message}")

        if @assignment.answered_by_on_date?(current_participant, @selected_date)
          flash[:alert] = "It looks like you've already submitted this assignment for #{@selected_date.strftime('%B %d, %Y')}."
          redirect_to participant_portal_root_path and return
        else
          flash.now[:alert] = "Some responses were already recorded by a concurrent submission. Please review and try again."
          @questions = @assignment.all_questions
          render :take_assignment, status: :conflict and return
        end
      rescue => e
        Rails.logger.error("Error in submit action: #{e.message}")
        flash.now[:alert] = "Error submitting assignment. Please try again."
        @questions = @assignment.all_questions
        render :take_assignment, status: :unprocessable_entity
      end
    end

    private

    def set_assignment
      @assignment = Assignment.find(params[:id])
    end

    def check_date_availability
      @selected_date = parse_date(params[:date])

      if @assignment.answered_by_on_date?(current_participant, @selected_date)
        flash[:error] = "You have already submitted this assignment for #{@selected_date.strftime('%B %d, %Y')}"
        redirect_to participant_portal_root_path
        return
      end

      unless @assignment.available_for_date?(current_participant, @selected_date)
        flash[:error] = "This assignment is not available for the selected date"
        redirect_to participant_portal_root_path
      end
    end

    def parse_date(date_param)
      return Date.current unless date_param.present?
      Date.parse(date_param)
    rescue ArgumentError
      Date.current
    end
  end
end
