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
              count: institute.training_programs.joins(:training_program_feedbacks).count
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
