module TrainerPortal
  class AssignmentsController < TrainerPortal::BaseController
    before_action :set_assignment, only: [ :show, :edit, :update, :destroy ]

    def index
      @assignments = Assignment.joins(training_program: :trainer)
        .where(training_programs: { trainer_id: current_trainer.id })
        .includes(:questions, :question_sets)
        .order(created_at: :desc)
    end

    def show
      @responses = @assignment.assignment_responses
        .includes(:participant)
        .order(created_at: :desc)
    end

    def new
      @assignment = Assignment.new
      @training_programs = current_trainer.training_programs
        .where(status: :ongoing)
    end

    def create
      @assignment = Assignment.new(assignment_params)

      if @assignment.save
        redirect_to trainer_portal_assignment_path(@assignment),
          notice: "Assignment was successfully created."
      else
        @training_programs = current_trainer.training_programs
          .where(status: :ongoing)
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @training_programs = current_trainer.training_programs
        .where(status: :ongoing)
    end

    def update
      if @assignment.update(assignment_params)
        redirect_to trainer_portal_assignment_path(@assignment),
          notice: "Assignment was successfully updated."
      else
        @training_programs = current_trainer.training_programs
          .where(status: :ongoing)
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @assignment.destroy
      redirect_to trainer_portal_assignments_path,
        notice: "Assignment was successfully deleted."
    end

    private

    def set_assignment
      @assignment = Assignment.joins(training_program: :trainer)
        .where(training_programs: { trainer_id: current_trainer.id })
        .find(params[:id])
    end

    def assignment_params
      params.require(:assignment).permit(
        :title,
        :description,
        :start_date,
        :end_date,
        :training_program_id,
        :active,
        question_ids: [],
        question_set_ids: []
      )
    end
  end
end
