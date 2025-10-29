module Admin
  class AdminController < Admin::BaseController
    before_action :clear_impersonation_session

    def dashboard
      # Basic Statistics
      @institutes_count = Institute.count
      @institute_admins_count = User.institute_admin.count

      # Get all institutes with their statistics
      @institutes = Institute.all.map do |institute|
        {
          id: institute.id,
          name: institute.name,
          stats: {
            programs: {
              total: institute.training_programs.count,
              active: institute.training_programs.where(status: :ongoing).count,
              completed: institute.training_programs.where(status: :completed).count
            },
            participants: {
              total: institute.participants.count,
              active: institute.participants.joins(:user).where(users: { active: true }).count
            },
            sections: {
              total: institute.sections.count,
              active: institute.sections.active.count
            },
            assignments: {
              total: institute.assignments.count,
              active: institute.assignments.active.count
            },
            questions: institute.questions.count,
            question_sets: institute.question_sets.count,
            feedbacks: {
              count: institute.training_programs.joins(:training_program_feedbacks).count,
              average_rating: (TrainingProgramFeedback.joins(:training_program).where(training_programs: { institute_id: institute.id }).average(:rating) || 0).to_f.round(1)
            }
          }
        }
      end

      # Data for charts
      @institution_stats = {
        labels: @institutes.map { |i| i[:name] },
        participants: @institutes.map { |i| i[:stats][:participants][:total] },
        active_participants: @institutes.map { |i| i[:stats][:participants][:active] },
        programs: @institutes.map { |i| i[:stats][:programs][:total] },
        active_programs: @institutes.map { |i| i[:stats][:programs][:active] },
        sections: @institutes.map { |i| i[:stats][:sections][:total] },
        assignments: @institutes.map { |i| i[:stats][:assignments][:total] },
        avg_ratings: @institutes.map { |i| i[:stats][:feedbacks][:average_rating] }
      }

      # Global totals
      @total_programs = TrainingProgram.count
      @active_programs_count = TrainingProgram.where(status: :ongoing).count

      @total_participants = Participant.count
      @total_approved_participants = Participant.joins(:user).where(users: { active: true }).count
      @total_not_approved_participants = Participant.joins(:user).where(users: { active: false }).count

      # Recent Data
      @recent_institutes = Institute.order(created_at: :desc).limit(5)
      @recent_programs = TrainingProgram.includes(:institute, :trainer)
                                      .order(created_at: :desc)
                                      .limit(5)
      @recent_feedbacks = TrainingProgramFeedback.includes(:training_program, :participant)
                                               .order(created_at: :desc)
                                               .limit(5)

  # Global totals for dashboard KPIs
  @total_sections = Section.count
  @active_sections = Section.active.count rescue Section.count

  @total_assignments = Assignment.count
  @active_assignments = Assignment.active.count rescue Assignment.count

  @total_questions = Question.count
  @total_question_sets = QuestionSet.count rescue 0

  @total_feedbacks = TrainingProgramFeedback.count
  @average_rating = (TrainingProgramFeedback.average(:rating) || 0).to_f.round(1)

  @total_trainers = Trainer.count
  # Total distinct responses (assignment + participant) for quick KPI on admin dashboard
  begin
    @total_responses = AssignmentResponse.joins(:participant)
                        .count("DISTINCT (assignment_responses.assignment_id, assignment_responses.participant_id)")
  rescue StandardError => e
    Rails.logger.warn("Could not compute total_responses for admin dashboard: "); Rails.logger.warn(e.message)
    @total_responses = 0
  end
    end

    # GET /admin/responses
    def responses
      # Total distinct submissions (assignment + participant)
      @total_responses = AssignmentResponse.joins(:participant)
                          .count("DISTINCT (assignment_responses.assignment_id, assignment_responses.participant_id)")

      # Per-institute response counts (optimized single SQL)
      sql = <<-SQL
        SELECT p.institute_id AS institute_id, i.name AS institute_name,
          COUNT(DISTINCT (ar.assignment_id, ar.participant_id)) AS responses_count
        FROM assignment_responses ar
        JOIN participants p ON p.id = ar.participant_id
        JOIN institutes i ON i.id = p.institute_id
        GROUP BY p.institute_id, i.name
        ORDER BY responses_count DESC, i.name
      SQL
      @institutes_responses = ActiveRecord::Base.connection.exec_query(sql).to_a
    end

    # GET /admin/institutes/:id/responses
    def institute_responses
      @institute = Institute.find(params[:id])
      # prepare filter collections
      @assignments = @institute.assignments.order(:title).select(:id, :title)
      @participants = @institute.participants.includes(:user).map { |p| [ p.id, p.user&.full_name || p.id ] }

      # Fetch recent responses for this institute with joins to avoid N+1
      responses = AssignmentResponse.joins(participant: :user)
                    .joins(:assignment, :question)
                    .where(participants: { institute_id: @institute.id })
                    .select("assignment_responses.*, assignments.title AS assignment_title, questions.title AS question_title, users.first_name, users.last_name")

      # Apply filters from params
      if params[:assignment_id].present?
        responses = responses.where(assignment_id: params[:assignment_id])
      end

      if params[:participant_id].present?
        responses = responses.where(participant_id: params[:participant_id])
      end

      if params[:status].present?
        case params[:status]
        when "answered"
          responses = responses.where("(assignment_responses.answer IS NOT NULL AND assignment_responses.answer <> '') OR (assignment_responses.selected_options IS NOT NULL)")
        when "unanswered"
          responses = responses.where("(assignment_responses.answer IS NULL OR assignment_responses.answer = '') AND (assignment_responses.selected_options IS NULL)")
        end
      end

      if params[:from].present?
        begin
          from = Date.parse(params[:from])
          responses = responses.where("assignment_responses.response_date >= ?", from)
        rescue ArgumentError
        end
      end

      if params[:to].present?
        begin
          to = Date.parse(params[:to])
          responses = responses.where("assignment_responses.response_date <= ?", to)
        rescue ArgumentError
        end
      end

      responses = responses.order("assignments.title, users.last_name, response_date DESC, assignment_responses.created_at DESC").limit(2000)

      # Group responses by assignment + participant so the view can render per-assignment blocks
      grouped = responses.group_by { |r| [ r.assignment_id, r.participant_id ] }

      @grouped_responses = grouped.map do |(assignment_id, participant_id), rows|
        first = rows.first
        {
          assignment_id: assignment_id,
          assignment_title: first.read_attribute("assignment_title") || first.assignment&.title,
          participant_id: participant_id,
          participant_name: [ first.read_attribute("first_name"), first.read_attribute("last_name") ].compact.join(" "),
          responses: rows.map do |r|
            {
              id: r.id,
              question_id: r.question_id,
              question_title: r.read_attribute("question_title") || r.question&.title,
              answer: r.answer,
              selected_options: r.selected_options,
              response_date: r.response_date,
              submitted_at: r.created_at
            }
          end
        }
      end
    end

    # GET /admin/institutes/:institute_id/responses/:id
    def response_detail
      @institute = Institute.find(params[:institute_id])

      # If assignment_id and participant_id are provided, render the full set of responses for that pair
      if params[:assignment_id].present? && params[:participant_id].present?
        @assignment = Assignment.find_by(id: params[:assignment_id])
        @participant = Participant.includes(:user).find_by(id: params[:participant_id], institute_id: @institute.id)
        unless @assignment && @participant
          redirect_to admin_institute_responses_path(@institute), alert: "Requested group not found."
          return
        end

        responses_relation = AssignmentResponse.includes(:question)
                      .where(assignment_id: @assignment.id, participant_id: @participant.id)
                      .order(:question_id)

        # load into array to compute simple statistics
        @responses = responses_relation.to_a

        @stats = {
          total: @responses.size,
          answered: @responses.count { |r| r.answer.present? || r.selected_options.present? },
          unanswered: @responses.count { |r| r.answer.blank? && r.selected_options.blank? },
          first_response_date: @responses.map(&:response_date).compact.min,
          last_response_date: @responses.map(&:response_date).compact.max
        }

        render :response_group and return
      end

      # Fallback: show single response by id
      @response = AssignmentResponse.includes(:assignment, :question, participant: :user).find(params[:id])
      # ensure the response belongs to the institute
      unless @response.participant&.institute_id == @institute.id
        redirect_to admin_institute_responses_path(@institute), alert: "Response not found for this institute."
        nil
      end
    end

    # GET /admin/participants_by_institute
    def participants_by_institute
      @institutes_participants = Institute.includes(participants: :user).map do |institute|
        total = institute.participants.count
        approved = institute.participants.joins(:user).where(users: { active: true }).count
        not_approved = total - approved
        {
          id: institute.id,
          name: institute.name,
          total: total,
          approved: approved,
          not_approved: not_approved
        }
      end
      @status_filter = params[:status]
    end

    # GET /admin/programs_by_institute
    def programs_by_institute
      @institutes_programs = Institute.includes(:training_programs).map do |institute|
        total = institute.training_programs.count
        active = institute.training_programs.where(status: :ongoing).count
        {
          id: institute.id,
          name: institute.name,
          total: total,
          active: active
        }
      end
    end

    # GET /admin/questions
    def questions
      @questions = Question.includes(:institute).order(created_at: :desc).limit(200)
    end

    # GET /admin/assignments
    def assignments
      @assignments = Assignment.includes(:institute).order(created_at: :desc).limit(200)
    end

    # GET /admin/trainers
    def trainers
      @trainers = Trainer.includes(:user, :institute).order(created_at: :desc).limit(200)
    end

    # GET /admin/institutes/:id/participants
    def institute_participants
      @institute = Institute.find(params[:id])
      participants = @institute.participants.includes(:user)
      if params[:status].present?
        case params[:status]
        when "approved"
          participants = participants.joins(:user).where(users: { active: true })
        when "not_approved"
          participants = participants.joins(:user).where(users: { active: false })
        end
      end
      @participants = participants.order("users.first_name").map do |p|
        {
          id: p.id,
          name: p.user.full_name,
          participant_type: p.participant_type,
          section: p.section&.name,
          active: p.user.active?
        }
      end
    end

    # GET /admin/institutes/:id/programs
    def institute_programs
      @institute = Institute.find(params[:id])
      programs = @institute.training_programs
      if params[:status] == "active"
        programs = programs.where(status: :ongoing)
      end
      @programs = programs.order(created_at: :desc).map do |pr|
        {
          id: pr.id,
          title: pr.title,
          trainer: pr.trainer&.user&.full_name,
          status: pr.status
        }
      end
    end

    private

    def clear_impersonation_session
      session.delete(:admin_institute_id)
      session.delete(:admin_return_to)
    end
  end
end
