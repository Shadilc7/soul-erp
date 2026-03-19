module Admin
  class AdminController < Admin::BaseController
    before_action :clear_impersonation_session

    def dashboard
      # Basic Statistics
      @institutes_count = Institute.count
      @institute_admins_count = User.institute_admin.count

      # Pre-aggregate institute statistics to avoid N+1/count warnings in Bullet.
      program_totals = TrainingProgram.group(:institute_id).count
      program_active_totals = TrainingProgram.where(status: :ongoing).group(:institute_id).count
      program_completed_totals = TrainingProgram.where(status: :completed).group(:institute_id).count

      participant_totals = Participant.group(:institute_id).count
      participant_active_totals = Participant.joins(:user).where(users: { active: true }).group(:institute_id).count

      section_totals = Section.group(:institute_id).count
      section_active_totals = Section.active.group(:institute_id).count

      assignment_totals = Assignment.group(:institute_id).count
      assignment_active_totals = Assignment.active.group(:institute_id).count

      question_totals = Question.group(:institute_id).count
      question_set_totals = QuestionSet.group(:institute_id).count

      feedback_totals = TrainingProgramFeedback.joins(:training_program).group("training_programs.institute_id").count
      feedback_avg_ratings = TrainingProgramFeedback.joins(:training_program).group("training_programs.institute_id").average(:rating)

      # Get all institutes with their statistics
      @institutes = Institute.select(:id, :name).map do |institute|
        institute_id = institute.id

        {
          id: institute_id,
          name: institute.name,
          stats: {
            programs: {
              total: program_totals[institute_id] || 0,
              active: program_active_totals[institute_id] || 0,
              completed: program_completed_totals[institute_id] || 0
            },
            participants: {
              total: participant_totals[institute_id] || 0,
              active: participant_active_totals[institute_id] || 0
            },
            sections: {
              total: section_totals[institute_id] || 0,
              active: section_active_totals[institute_id] || 0
            },
            assignments: {
              total: assignment_totals[institute_id] || 0,
              active: assignment_active_totals[institute_id] || 0
            },
            questions: question_totals[institute_id] || 0,
            question_sets: question_set_totals[institute_id] || 0,
            feedbacks: {
              count: feedback_totals[institute_id] || 0,
              average_rating: (feedback_avg_ratings[institute_id] || 0).to_f.round(1)
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
      @recent_programs = TrainingProgram.includes(:institute, trainer: :user)
                                      .order(created_at: :desc)
                                      .limit(5)
      @recent_feedbacks = TrainingProgramFeedback.includes(:training_program, participant: :user)
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

      # Note: status filter removed — we no longer allow answered/unanswered filtering here

      # Date filters: use timezone-aware day bounds so 'To' includes the whole day
      if params[:from].present?
        begin
          from = Time.zone.parse(params[:from]).beginning_of_day
          responses = responses.where("assignment_responses.response_date >= ?", from)
        rescue StandardError
          # ignore invalid dates
        end
      end

      if params[:to].present?
        begin
          to = Time.zone.parse(params[:to]).end_of_day
          responses = responses.where("assignment_responses.response_date <= ?", to)
        rescue StandardError
          # ignore invalid dates
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
      @institutes = Institute.all.order(:name)

      questions = Question.includes(:institute).order(created_at: :desc)

      if params[:institute_id].present?
        questions = questions.where(institute_id: params[:institute_id])
      end

      @questions = questions.limit(200)
    end

    # GET /admin/assignments
    def assignments
      @institutes = Institute.all.order(:name)

      assignments = Assignment.includes(:institute).order(created_at: :desc)

      if params[:institute_id].present?
        assignments = assignments.where(institute_id: params[:institute_id])
      end

      @assignments = assignments.limit(200)
    end

    # GET /admin/trainers
    def trainers
      @institutes = Institute.all.order(:name)

      trainers = Trainer.includes(:user, :institute).order(created_at: :desc)

      if params[:institute_id].present?
        trainers = trainers.where(institute_id: params[:institute_id])
      end

      @trainers = trainers.limit(200)
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
