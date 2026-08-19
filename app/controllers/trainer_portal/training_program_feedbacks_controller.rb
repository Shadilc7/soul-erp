module TrainerPortal
  class TrainingProgramFeedbacksController < TrainerPortal::BaseController
    before_action :set_training_program, only: [ :show ]

    def index
      @training_programs = current_trainer.training_programs
        .includes(:training_program_feedbacks)
        .order(created_at: :desc)
    end

    def show
      @feedbacks = @training_program.training_program_feedbacks
        .includes(participant: :user)
        .order(created_at: :desc)

      @total_feedbacks_count = @feedbacks.count
      @avg_rating = @total_feedbacks_count.positive? ? @feedbacks.average(:rating).to_f.round(1) : 0.0

      raw_rating_counts = @feedbacks.group(:rating).count
      @rating_distribution = [5, 4, 3, 2, 1].map do |stars|
        count = raw_rating_counts[stars] || raw_rating_counts[stars.to_i] || 0
        pct = @total_feedbacks_count.positive? ? ((count.to_f / @total_feedbacks_count) * 100).round(1) : 0.0
        {
          stars: stars,
          count: count,
          percentage: pct
        }
      end
      positive_count = (raw_rating_counts[5] || 0) + (raw_rating_counts[4] || 0)
      @positive_rating_pct = @total_feedbacks_count.positive? ? ((positive_count.to_f / @total_feedbacks_count) * 100).round : 0
    end

    private

    def set_training_program
      @training_program = current_trainer.training_programs.find(params[:id])
    end
  end
end
