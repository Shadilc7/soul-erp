module InstituteAdmin
  class AssignmentsController < InstituteAdmin::BaseController
    before_action :set_assignment, only: [ :show, :edit, :update, :destroy ]

    def index
      @assignments = current_institute.assignments
        .order(created_at: :desc)
    end

    def show
      @assignment = current_institute.assignments
        .includes(:section, participants: :user)
        .find(params[:id])
    end

    def new
      @assignment = current_institute.assignments.new
    end

    def create
      cleaned_params = assignment_params.to_h
      cleaned_params["question_ids"]&.reject!(&:blank?)
      cleaned_params["question_set_ids"]&.reject!(&:blank?)
      cleaned_params["participant_ids"]&.reject!(&:blank?)

      # Extract the association IDs
      question_ids = cleaned_params.delete("question_ids") || []
      question_set_ids = cleaned_params.delete("question_set_ids") || []
      participant_ids = cleaned_params.delete("participant_ids") || []

      @assignment = current_institute.assignments.new(cleaned_params)

      ActiveRecord::Base.transaction do
        # First save the basic assignment
        if @assignment.save
          # Build all associations before validation
          question_ids.each do |qid|
            @assignment.assignment_questions.build(question_id: qid)
          end

          question_set_ids.each do |qsid|
            @assignment.assignment_question_sets.build(question_set_id: qsid)
          end

          participant_ids.each do |pid|
            @assignment.assignment_participants.build(participant_id: pid)
          end

          # Save all associations at once
          if @assignment.assignment_questions.all?(&:valid?) &&
             @assignment.assignment_question_sets.all?(&:valid?) &&
             @assignment.assignment_participants.all?(&:valid?)

            @assignment.assignment_questions.each(&:save!)
            @assignment.assignment_question_sets.each(&:save!)
            @assignment.assignment_participants.each(&:save!)

            # Final validation of the complete assignment
            if @assignment.valid?
              redirect_to institute_admin_assignments_path, notice: "Assignment created successfully."
              return
            end
          end

          # If we get here, something failed
          raise ActiveRecord::Rollback
        end
      end

      # If we get here, the transaction was rolled back
      Rails.logger.debug "Assignment creation failed: #{@assignment.errors.full_messages}"
      render :new
    end

    def edit
      @sections = current_institute.sections.active
      @selected_sections = @assignment.sections
      @selected_participants = @assignment.participants.includes(:user)
    end

    def update
      cleaned_params = assignment_params.to_h
      cleaned_params["question_ids"]&.reject!(&:blank?)
      cleaned_params["question_set_ids"]&.reject!(&:blank?)
      cleaned_params["participant_ids"]&.reject!(&:blank?)

      # Extract the association IDs
      question_ids = cleaned_params.delete("question_ids") || []
      question_set_ids = cleaned_params.delete("question_set_ids") || []
      participant_ids = cleaned_params.delete("participant_ids") || []
      section_ids = cleaned_params.delete("section_ids") || []

      ActiveRecord::Base.transaction do
        # Update basic assignment attributes
        if @assignment.update(cleaned_params)
          # Clear existing associations
          @assignment.assignment_questions.destroy_all
          @assignment.assignment_question_sets.destroy_all
          @assignment.assignment_participants.destroy_all

          # Rebuild all associations
          question_ids.each do |qid|
            @assignment.assignment_questions.build(question_id: qid)
          end

          question_set_ids.each do |qsid|
            @assignment.assignment_question_sets.build(question_set_id: qsid)
          end

          participant_ids.each do |pid|
            @assignment.assignment_participants.build(participant_id: pid)
          end

          # Save all associations at once
          if @assignment.assignment_questions.all?(&:valid?) &&
             @assignment.assignment_question_sets.all?(&:valid?) &&
             @assignment.assignment_participants.all?(&:valid?)

            @assignment.assignment_questions.each(&:save!)
            @assignment.assignment_question_sets.each(&:save!)
            @assignment.assignment_participants.each(&:save!)

            # Final validation of the complete assignment
            if @assignment.valid?
              redirect_to institute_admin_assignments_path, notice: "Assignment updated successfully."
              return
            end
          end

          # If we get here, something failed
          raise ActiveRecord::Rollback
        end
      end

      # If we get here, the transaction was rolled back
      Rails.logger.debug "Assignment update failed: #{@assignment.errors.full_messages}"
      @sections = current_institute.sections.active
      @selected_sections = @assignment.sections
      @selected_participants = @assignment.participants.includes(:user)
      render :edit, status: :unprocessable_entity
    end

    def destroy
      @assignment.destroy
      redirect_to institute_admin_assignments_path, notice: "Assignment was successfully deleted."
    end

    private

    def set_assignment
      @assignment = current_institute.assignments
        .includes(:sections, participants: :user)
        .find(params[:id])
    end

    def assignment_params
      params.require(:assignment).permit(
        :title, :description, :start_date, :end_date, :active, :assignment_type,
        :section_id,
        section_ids: [],
        participant_ids: [],
        question_ids: [],
        question_set_ids: []
      )
    end
  end
end
