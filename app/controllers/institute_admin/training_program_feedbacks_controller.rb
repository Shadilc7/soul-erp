module InstituteAdmin
  class TrainingProgramFeedbacksController < InstituteAdmin::BaseController
    before_action :set_training_program

    def index
      @all_feedbacks = @training_program.training_program_feedbacks
        .includes(participant: :user)
        .order(created_at: :desc)

      @feedbacks = @all_feedbacks

      if params[:rating].present?
        @feedbacks = @feedbacks.where(rating: params[:rating])
      end

      if params[:participant_type].present?
        @feedbacks = @feedbacks.joins(:participant).where(participants: { participant_type: params[:participant_type] })
      end

      if params[:search].present?
        query = "%#{params[:search].downcase}%"
        @feedbacks = @feedbacks.joins(participant: :user).where(
          "LOWER(users.first_name) LIKE :q OR LOWER(users.last_name) LIKE :q OR LOWER(training_program_feedbacks.content) LIKE :q",
          q: query
        )
      end

      # KPI Metrics
      @total_feedbacks_count = @all_feedbacks.count
      @avg_rating = @total_feedbacks_count.positive? ? @all_feedbacks.average(:rating).to_f.round(1) : 0.0
      @five_star_count = @all_feedbacks.where(rating: 5).count
      @participant_types_count = @all_feedbacks.joins(:participant).pluck("participants.participant_type").compact.uniq.count
    end

    private

    def set_training_program
      @training_program = current_institute.training_programs.find(params[:training_program_id])
    end
  end
end
