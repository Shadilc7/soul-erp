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

    def import_setup
      bank_id = params[:question_bank_id]
      selected_category_ids = params[:category_ids]

      @question_bank = QuestionBank.find_by(id: bank_id)

      if @question_bank.nil?
        redirect_to institute_admin_assignments_path, alert: "Selected Question Bank not found."
        return
      end

      categories_scope = @question_bank.question_categories.where(active: true)
      if selected_category_ids.present?
        categories_scope = categories_scope.where(id: selected_category_ids)
      end

      @categories = categories_scope.includes(
        :questions,
        question_bundles: { question_bundle_items: { question: :options } }
      )

      if @categories.empty?
        redirect_to institute_admin_assignments_path, alert: "No active categories selected for import."
        return
      end

      @custom_questions = current_institute.questions.includes(:options).order(created_at: :desc)
      @sections = current_institute.sections.active.joins(:participants).distinct
      @participants = current_institute.participants.active.includes(:user)
    end

    def finalize_import
      assignments_data = params[:assignments]

      if assignments_data.blank?
        redirect_to institute_admin_assignments_path, alert: "No assignment configuration received."
        return
      end

      created_assignments = []

      ActiveRecord::Base.transaction do
        assignments_data.each do |category_id, data|
          category = QuestionCategory.find_by(id: category_id)
          next unless category

          start_date = data[:start_date].present? ? Date.parse(data[:start_date]) : Date.current
          duration = (category.duration_days.to_i > 0) ? category.duration_days.to_i : 30
          end_date = data[:end_date].present? ? Date.parse(data[:end_date]) : (start_date + duration.days)
          assignment_type = data[:assignment_type].presence || "individual"
          title = data[:title].presence || category.name
          description = data[:description].presence || category.description

          assignment = current_institute.assignments.build(
            title: title,
            description: description,
            start_date: start_date,
            end_date: end_date,
            assignment_type: assignment_type,
            active: data[:active].nil? ? true : (data[:active] == "1" || data[:active] == true),
            question_category: category
          )

          assignment.save!(validate: false)

          order_index = 0
          imported_question_ids = Set.new
          has_q_param = data.key?(:question_ids)
          selected_qids = data[:question_ids]&.map(&:to_i)&.reject(&:zero?) || []

          bundle_items = data[:bundle_items] || data["bundle_items"]
          if bundle_items.present?
            bundle_items.each do |bi|
              bi_hash = bi.respond_to?(:to_unsafe_h) ? bi.to_unsafe_h : bi
              qid = (bi_hash[:question_id] || bi_hash["question_id"]).to_i
              next if qid.zero? || imported_question_ids.include?(qid)
              next if has_q_param && !selected_qids.include?(qid)

              b_name = (bi_hash[:bundle_name] || bi_hash["bundle_name"]).to_s.presence || "Part 1"

              assignment.assignment_questions.create!(
                question_id: qid,
                bundle_name: b_name,
                order_number: order_index += 1
              )
              imported_question_ids.add(qid)
            end
          end

          category.question_bundles.order(:position).each do |bundle|
            bundles_param = data[:bundles] || data["bundles"]
            bundle_override = bundles_param ? (bundles_param[bundle.id.to_s] || bundles_param[bundle.id.to_i] || bundles_param[bundle.id]) : nil
            custom_bundle_name = if bundle_override.respond_to?(:[])
              (bundle_override[:name] || bundle_override["name"]).presence
            end
            effective_bundle_name = custom_bundle_name || bundle.name

            bundle.question_bundle_items.order(:position).each do |item|
              qid = item.question_id
              next if qid.blank? || imported_question_ids.include?(qid)

              if !has_q_param || selected_qids.include?(qid)
                assignment.assignment_questions.create!(
                  question_id: qid,
                  bundle_name: effective_bundle_name,
                  order_number: order_index += 1
                )
                imported_question_ids.add(qid)
              end
            end
          end

          if assignment_type == "section"
            sec_ids = data[:section_ids]&.reject(&:blank?) || []
            sec_ids.uniq.each do |sid|
              assignment.assignment_sections.create!(section_id: sid)
            end

            part_ids = data[:participant_ids]&.reject(&:blank?) || []
            if part_ids.any?
              part_ids.uniq.each do |pid|
                assignment.assignment_participants.create!(participant_id: pid)
              end
            elsif sec_ids.any?
              current_institute.participants.active.where(section_id: sec_ids).pluck(:id).each do |pid|
                assignment.assignment_participants.create!(participant_id: pid)
              end
            end
          else
            part_ids = data[:participant_ids]&.reject(&:blank?) || []
            part_ids.uniq.each do |pid|
              assignment.assignment_participants.create!(participant_id: pid)
            end
          end

          created_assignments << assignment
        end
      end

      titles_str = created_assignments.map(&:title).join(", ")
      redirect_to institute_admin_assignments_path, notice: "Successfully created #{created_assignments.size} assignment(s): #{titles_str}!"
    rescue => e
      Rails.logger.error("Failed to finalize Question Bank import: #{e.message}\n#{e.backtrace.join("\n")}")
      redirect_to institute_admin_assignments_path, alert: "An error occurred while creating assignments: #{e.message}"
    end

    def import_question_bank
      redirect_to import_setup_institute_admin_assignments_path(
        question_bank_id: params[:question_bank_id],
        category_ids: params[:category_ids]
      )
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

      question_bundle_items = cleaned_params.delete("question_bundle_items") || []
      question_ids = cleaned_params.delete("question_ids") || []
      question_set_ids = cleaned_params.delete("question_set_ids") || []
      participant_ids = cleaned_params.delete("participant_ids") || []

      @assignment = current_institute.assignments.new(cleaned_params)

      ActiveRecord::Base.transaction do
        if @assignment.save
          if question_bundle_items.any?
            added_qids = Set.new
            question_bundle_items.each do |item|
              qid = (item["question_id"] || item[:question_id]).to_i
              bname = item["bundle_name"] || item[:bundle_name]
              next if qid.zero? || added_qids.include?(qid)
              added_qids.add(qid)
              @assignment.assignment_questions.build(question_id: qid, bundle_name: bname, order_number: added_qids.size)
            end
          else
            added_qids = Set.new
            question_ids.each do |qid|
              qid_i = qid.to_i
              next if qid_i.zero? || added_qids.include?(qid_i)
              added_qids.add(qid_i)
              @assignment.assignment_questions.build(question_id: qid_i, order_number: added_qids.size)
            end
          end

          question_set_ids.uniq.reject(&:blank?).each do |qsid|
            @assignment.assignment_question_sets.build(question_set_id: qsid)
          end

          participant_ids.uniq.reject(&:blank?).each do |pid|
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

      question_bundle_items = cleaned_params.delete("question_bundle_items") || []
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

        if question_bundle_items.any?
          added_qids = Set.new
          question_bundle_items.each do |item|
            qid = (item["question_id"] || item[:question_id]).to_i
            bname = item["bundle_name"] || item[:bundle_name]
            next if qid.zero? || added_qids.include?(qid)
            added_qids.add(qid)
            @assignment.assignment_questions.build(question_id: qid, bundle_name: bname, order_number: added_qids.size)
          end
        else
          added_qids = Set.new
          question_ids.each do |qid|
            qid_i = qid.to_i
            next if qid_i.zero? || added_qids.include?(qid_i)
            added_qids.add(qid_i)
            @assignment.assignment_questions.build(question_id: qid_i, order_number: added_qids.size)
          end
        end

        question_set_ids.uniq.reject(&:blank?).each do |qsid|
          @assignment.assignment_question_sets.build(question_set_id: qsid)
        end

        participant_ids.uniq.reject(&:blank?).each do |pid|
          @assignment.assignment_participants.build(participant_id: pid)
        end

        section_ids.uniq.reject(&:blank?).each do |sec_id|
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
        question_set_ids: [],
        question_bundle_items: [:question_id, :bundle_name]
      )
    end
  end
end
