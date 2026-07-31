module InstituteAdmin
  class AssignmentsController < InstituteAdmin::BaseController
    before_action :set_assignment, only: [ :show, :edit, :update, :destroy ]

    def index
      scope = current_institute.assignments.includes(:question_category)

      if params[:search].present?
        query = "%#{params[:search].strip}%"
        scope = scope.where("assignments.title ILIKE ? OR assignments.description ILIKE ?", query, query)
      end

      if params[:assignment_type].present?
        scope = scope.where(assignment_type: params[:assignment_type])
      end

      if params[:question_category_id].present?
        scope = scope.where(question_category_id: params[:question_category_id])
      end

      @total_assignments_count = current_institute.assignments.count
      @active_assignments_count = current_institute.assignments.where(active: true).count
      @assignments = scope.order(created_at: :desc)
      assignment_ids = @assignments.map(&:id)

      @sections_count_by_assignment_id = AssignmentSection.where(assignment_id: assignment_ids)
                                                           .group(:assignment_id)
                                                           .count
      @participants_count_by_assignment_id = AssignmentParticipant.where(assignment_id: assignment_ids)
                                                                 .group(:assignment_id)
                                                                 .count
      @questions_count_by_assignment_id = AssignmentQuestion.where(assignment_id: assignment_ids)
                                                             .group(:assignment_id)
                                                             .count
      @question_sets_count_by_assignment_id = AssignmentQuestionSet.where(assignment_id: assignment_ids)
                                                                   .group(:assignment_id)
                                                                   .count

      @total_participants_assigned_count = @participants_count_by_assignment_id.values.sum
      @total_questions_assigned_count = @questions_count_by_assignment_id.values.sum

      @categories_for_filter = QuestionCategory.where(id: current_institute.assignments.select(:question_category_id).where.not(question_category_id: nil).distinct).order(:name)
      @available_question_banks = QuestionBank.where(active: true).includes(:question_categories).order(:name)
    end

    def import_question_bank
      bank_id = params[:question_bank_id]
      question_bank = QuestionBank.find_by(id: bank_id)

      if question_bank.nil?
        redirect_to institute_admin_assignments_path, alert: "Selected Question Bank not found."
        return
      end

      categories = question_bank.question_categories.where(active: true).includes(
        :questions,
        question_bundles: { question_bundle_items: :question }
      )

      if categories.empty?
        redirect_to institute_admin_assignments_path, alert: "The selected Question Bank has no active categories to import."
        return
      end

      created_assignments_count = 0

      ActiveRecord::Base.transaction do
        categories.each do |category|
          duration = category.duration_days.to_i
          duration = 30 if duration <= 0

          start_date = Date.current
          end_date = start_date + duration.days

          assignment = current_institute.assignments.build(
            title: category.name,
            description: category.description,
            start_date: start_date,
            end_date: end_date,
            assignment_type: "individual",
            active: true,
            question_category: category
          )

          assignment.save!(validate: false)

          ordered_question_ids = []

          category.question_bundles.order(:position).each do |bundle|
            bundle.question_bundle_items.order(:position).each do |item|
              ordered_question_ids << item.question_id if item.question_id.present?
            end
          end

          category_q_ids = category.questions.pluck(:id)
          unbundled_q_ids = category_q_ids - ordered_question_ids
          ordered_question_ids.concat(unbundled_q_ids)
          ordered_question_ids.uniq!

          ordered_question_ids.each_with_index do |qid, index|
            assignment.assignment_questions.create!(
              question_id: qid,
              order_number: index + 1
            )
          end

          created_assignments_count += 1
        end
      end

      redirect_to institute_admin_assignments_path, notice: "Successfully imported '#{question_bank.name}' and created #{created_assignments_count} assignment(s)!"
    rescue => e
      Rails.logger.error("Failed to import Question Bank: #{e.message}\n#{e.backtrace.join("\n")}")
      redirect_to institute_admin_assignments_path, alert: "An error occurred while importing the Question Bank: #{e.message}"
    end

    def show
      @grouped_questions = @assignment.questions_grouped_by_bundle
    end

    def new
      @assignment = current_institute.assignments.new
    end

    def create
      cleaned_params = assignment_params.to_h
      cleaned_params["question_ids"]&.reject!(&:blank?)
      cleaned_params["question_set_ids"]&.reject!(&:blank?)
      cleaned_params["participant_ids"]&.reject!(&:blank?)

      question_ids = cleaned_params.delete("question_ids") || []
      question_set_ids = cleaned_params.delete("question_set_ids") || []
      participant_ids = cleaned_params.delete("participant_ids") || []

      @assignment = current_institute.assignments.new(cleaned_params)

      ActiveRecord::Base.transaction do
        if @assignment.save
          question_ids.each_with_index do |qid, index|
            @assignment.assignment_questions.build(question_id: qid, order_number: index + 1)
          end

          question_set_ids.each do |qsid|
            @assignment.assignment_question_sets.build(question_set_id: qsid)
          end

          participant_ids.each do |pid|
            @assignment.assignment_participants.build(participant_id: pid)
          end

          if @assignment.assignment_questions.all?(&:valid?) &&
             @assignment.assignment_question_sets.all?(&:valid?) &&
             @assignment.assignment_participants.all?(&:valid?)

            @assignment.assignment_questions.each(&:save!)
            @assignment.assignment_question_sets.each(&:save!)
            @assignment.assignment_participants.each(&:save!)

            if @assignment.valid?
              redirect_to institute_admin_assignments_path, notice: "Assignment created successfully."
              return
            end
          end

          raise ActiveRecord::Rollback
        end
      end

      Rails.logger.debug "Assignment creation failed: #{@assignment.errors.full_messages}"
      render :new
    end

    def edit
      @sections = current_institute.sections.active
      @selected_sections = @assignment.sections
      @selected_participants = @assignment.participants.includes(:user)
      @grouped_questions = @assignment.edit_questions_grouped_by_bundle
    end

    def update
      cleaned_params = assignment_params.to_h
      cleaned_params["question_ids"]&.reject!(&:blank?)
      cleaned_params["question_set_ids"]&.reject!(&:blank?)
      cleaned_params["participant_ids"]&.reject!(&:blank?)

      question_ids = cleaned_params.delete("question_ids") || []
      question_set_ids = cleaned_params.delete("question_set_ids") || []
      participant_ids = cleaned_params.delete("participant_ids") || []
      section_ids = cleaned_params.delete("section_ids") || []

      @assignment.assign_attributes(cleaned_params)

      ActiveRecord::Base.transaction do
        @assignment.assignment_questions.destroy_all
        @assignment.assignment_question_sets.destroy_all
        @assignment.assignment_participants.destroy_all
        @assignment.assignment_sections.destroy_all

        question_ids.each_with_index do |qid, index|
          @assignment.assignment_questions.build(question_id: qid, order_number: index + 1)
        end

        question_set_ids.each do |qsid|
          @assignment.assignment_question_sets.build(question_set_id: qsid)
        end

        participant_ids.each do |pid|
          @assignment.assignment_participants.build(participant_id: pid)
        end

        section_ids.each do |sec_id|
          @assignment.assignment_sections.build(section_id: sec_id)
        end

        if @assignment.save
          redirect_to institute_admin_assignment_path(@assignment), notice: "Assignment updated successfully."
          return
        else
          raise ActiveRecord::Rollback
        end
      end

      @sections = current_institute.sections.active
      @selected_sections = @assignment.sections
      @selected_participants = @assignment.participants.includes(:user)
      @grouped_questions = @assignment.edit_questions_grouped_by_bundle
      render :edit, status: :unprocessable_entity
    end

    def destroy
      @assignment.destroy
      redirect_to institute_admin_assignments_path, notice: "Assignment was successfully deleted."
    end

    private

    def set_assignment
      @assignment = current_institute.assignments
        .includes(:question_category)
        .find(params[:id])
    end

    def assignment_params
      params.require(:assignment).permit(
        :title, :description, :start_date, :end_date, :active, :assignment_type,
        :section_id, :question_category_id,
        section_ids: [],
        participant_ids: [],
        question_ids: [],
        question_set_ids: []
      )
    end
  end
end
