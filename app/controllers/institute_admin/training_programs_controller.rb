module InstituteAdmin
  class TrainingProgramsController < InstituteAdmin::BaseController
    before_action :set_training_program, only: [ :show, :edit, :update, :destroy, :mark_completed ]

    def index
      @training_programs = current_institute.training_programs
        .includes(:trainer, :section, :participant)
        .order(created_at: :desc)

      if params[:program_type].present?
        @training_programs = @training_programs.where(program_type: params[:program_type])
      end

      if params[:status].present?
        @training_programs = @training_programs.where(status: params[:status])
      end

      if params[:search].present?
        @training_programs = @training_programs.where("title ILIKE ?", "%#{params[:search]}%")
      end

      if params[:view] == "feedbacks"
        # Include training program feedbacks for the feedbacks view
        @training_programs = @training_programs.includes(:training_program_feedbacks)
        render :feedbacks
      end
    end

    def show
    end

    def new
      @training_program = current_institute.training_programs.new
      @trainers = current_institute.trainers.includes(:user).active
      @sections = current_institute.sections.active
      @participants = current_institute.participants.includes(:user).active
    end

    def create
      @training_program = current_institute.training_programs.new(training_program_params)

      # Handle participant IDs from the form
      if params[:training_program][:participant_ids].present?
        @training_program.participant_ids = params[:training_program][:participant_ids]
      end

      # Handle section IDs from the form
      if params[:training_program][:section_ids].present?
        @training_program.section_ids = params[:training_program][:section_ids]
      end

      if @training_program.save
        redirect_to institute_admin_training_programs_path, notice: "Training program was successfully created."
      else
        @trainers = current_institute.trainers.includes(:user).active
        @sections = current_institute.sections.active
        @participants = current_institute.participants.includes(:user).active
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @trainers = current_institute.trainers.includes(:user).active
      @sections = current_institute.sections.active
      @participants = current_institute.participants.includes(:user).active
    end

    def update
      # Handle participant IDs from the form
      if params[:training_program][:participant_ids].present?
        @training_program.participant_ids = params[:training_program][:participant_ids]
      end

      # Handle section IDs from the form
      if params[:training_program][:section_ids].present?
        @training_program.section_ids = params[:training_program][:section_ids]
      end

      if @training_program.update(training_program_params)
        redirect_to institute_admin_training_programs_path, notice: "Training program was successfully updated."
      else
        @trainers = current_institute.trainers.includes(:user).active
        @sections = current_institute.sections.active
        @participants = current_institute.participants.includes(:user).active
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @training_program.destroy
      redirect_to institute_admin_training_programs_path,
        notice: "Training program was successfully deleted."
    end

    def mark_completed
      if @training_program.update(status: :completed)
        redirect_to institute_admin_training_program_path(@training_program),
          notice: "Training program has been marked as completed."
      else
        redirect_to institute_admin_training_program_path(@training_program),
          alert: "Failed to mark training program as completed."
      end
    end

    private

    def set_training_program
      @training_program = current_institute.training_programs.find(params[:id])
    end

    def training_program_params
      params.require(:training_program).permit(
        :title, :description, :start_date, :end_date,
        :program_type, :trainer_id, :section_id, :participant_id,
        :status, participant_ids: [], section_ids: []
      )
    end
  end
end
