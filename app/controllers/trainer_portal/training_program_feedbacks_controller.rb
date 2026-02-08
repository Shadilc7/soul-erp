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
    end

    private

    def set_training_program
      @training_program = current_trainer.training_programs.find(params[:id])
    end
  end
end
