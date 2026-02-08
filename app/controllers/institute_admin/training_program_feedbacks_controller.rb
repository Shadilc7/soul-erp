module InstituteAdmin
  class TrainingProgramFeedbacksController < InstituteAdmin::BaseController
    before_action :set_training_program

    def index
      @feedbacks = @training_program.training_program_feedbacks
        .includes(participant: :user)
        .order(created_at: :desc)
    end

    private

    def set_training_program
      @training_program = current_institute.training_programs.find(params[:training_program_id])
    end
  end
end
