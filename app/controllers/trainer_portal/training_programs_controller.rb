module TrainerPortal
  class TrainingProgramsController < TrainerPortal::BaseController
    before_action :set_training_program, only: [ :show, :edit, :update, :destroy, :mark_completed ]

    def index
      @training_programs = current_trainer.training_programs
        .includes(:section, :participants)
        .order(created_at: :desc)
    end

    def show
      @training_program = current_trainer.training_programs
        .includes(:institute, :sections, :training_program_participants, participants: [ :user, :section ])
        .find(params[:id])

      @participants = @training_program.participants
        .includes(:user, :section)
        .order("users.first_name ASC, users.last_name ASC")
    end

    def new
      @training_program = TrainingProgram.new
      @sections = current_institute.sections.active
    end

    def create
      @training_program = current_trainer.training_programs.build(training_program_params)

      if @training_program.save
        redirect_to trainer_portal_training_program_path(@training_program),
          notice: "Training program was successfully created."
      else
        @sections = current_institute.sections.active
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @sections = current_institute.sections.active
    end

    def update
      if @training_program.update(training_program_params)
        redirect_to trainer_portal_training_program_path(@training_program),
          notice: "Training program was successfully updated."
      else
        @sections = current_institute.sections.active
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @training_program.destroy
      redirect_to trainer_portal_training_programs_path,
        notice: "Training program was successfully deleted."
    end

    def mark_completed
      if @training_program.update(status: :completed)
        redirect_to trainer_portal_training_program_path(@training_program),
          notice: "Training program has been marked as completed."
      else
        redirect_to trainer_portal_training_program_path(@training_program),
          alert: "Failed to mark training program as completed."
      end
    end

    private

    def set_training_program
      @training_program = current_trainer.training_programs.find(params[:id])
    end

    def training_program_params
      params.require(:training_program).permit(
        :title,
        :description,
        :start_date,
        :end_date,
        :program_type,
        :section_id,
        :participant_id,
        participant_ids: [],
        section_ids: []
      )
    end
  end
end
