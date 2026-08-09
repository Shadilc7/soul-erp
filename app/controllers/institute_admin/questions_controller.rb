module InstituteAdmin
  class QuestionsController < InstituteAdmin::BaseController
    before_action :set_question, only: [ :show, :edit, :update, :destroy ]

    def index
      @institute = current_institute
      @all_questions = @institute.questions.includes(:options).order(position: :asc, created_at: :desc)
      @questions = @all_questions
      @question_types = Question.question_types.keys

      if params[:search].present?
        query = "%#{params[:search].downcase}%"
        @questions = @questions.where("LOWER(title) LIKE :q OR LOWER(display_name) LIKE :q", q: query)
      end

      if params[:question_type].present?
        @questions = @questions.where(question_type: params[:question_type])
      end

      if params[:status].present?
        is_active = params[:status] == "active"
        @questions = @questions.where(active: is_active)
      end

      # KPI Metrics (Calculated on filtered set)
      @total_questions_count = @questions.count
      @active_questions_count = @questions.where(active: true).count
      @types_count = @questions.pluck(:question_type).compact.uniq.count
      @required_questions_count = @questions.where(required: true).count

      respond_to do |format|
        format.html
        format.csv {
          send_data generate_questions_csv(@questions),
                    filename: "questions_bank_#{Date.current}.csv",
                    type: "text/csv"
        }
        format.pdf {
          pdf_data = generate_questions_pdf_with_ferrum
          send_data pdf_data,
                    filename: "questions_bank_#{Date.current}.pdf",
                    type: "application/pdf",
                    disposition: "inline"
        }
      end
    end

    def reorder
      if params[:question_ids].is_a?(Array)
        params[:question_ids].each_with_index do |id, index|
          current_institute.questions.where(id: id).update_all(position: index + 1)
        end
      end
      render json: { status: "success", message: "Question order updated successfully." }
    end

    def show
    end

    def new
      @question = current_institute.questions.build
    end

    def create
      begin
        # Get the parameters first
        question_parameters = sanitize_question_params(question_params)

        @question = current_institute.questions.build(question_parameters)

        # Final safety check before saving
        ensure_options_have_text(@question) if @question.requires_options?

        if @question.save
          redirect_to institute_admin_question_path(@question), notice: "Question was successfully created."
        else
          render :new, status: :unprocessable_entity
        end
      rescue => e
        # Log the error
        Rails.logger.error("Error creating question: #{e.message}")
        Rails.logger.error(e.backtrace.join("\n"))

        # Create a new question object for the form
        @question = current_institute.questions.build(question_params)

        # Add error message
        flash.now[:error] = "An error occurred while creating the question. Please try again."
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      begin
        # Get the parameters first
        question_parameters = sanitize_question_params(question_params)

        # Final safety check before updating
        @question.assign_attributes(question_parameters)
        ensure_options_have_text(@question) if @question.requires_options?

        if @question.save
          redirect_to institute_admin_question_path(@question), notice: "Question was successfully updated."
        else
          render :edit, status: :unprocessable_entity
        end
      rescue => e
        # Log the error
        Rails.logger.error("Error updating question: #{e.message}")
        Rails.logger.error(e.backtrace.join("\n"))

        # Add error message
        flash.now[:error] = "An error occurred while updating the question. Please try again."
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @question = current_institute.questions.find(params[:id])

      if @question.destroy
        redirect_to institute_admin_questions_path, notice: "Question was successfully deleted."
      else
        error_msg = @question.errors.full_messages.to_sentence.presence || "Cannot delete Question because it is in use by assignments."
        redirect_to institute_admin_questions_path, alert: error_msg
      end
    end

    def duplicate
      begin
        original_question = current_institute.questions.includes(:options).find(params[:id])

        # Skip validation temporarily for the new question
        new_question = nil

        ActiveRecord::Base.transaction do
          # For question types that require options, we need to handle differently
          if original_question.requires_options?
            # First, create the question with validation skipped
            new_question = current_institute.questions.new(
              title: "Copy of #{original_question.title}",
              description: original_question.description,
              display_name: original_question.display_name ? "Copy of #{original_question.display_name}" : nil,
              question_type: original_question.question_type,
              required: original_question.required,
              active: original_question.active,
              max_rating: original_question.max_rating,
              duration_days: original_question.duration_days,
              from_day: original_question.from_day,
              to_day: original_question.to_day
            )

            # Temporarily disable validation
            new_question.validate_options_on_save = false if new_question.respond_to?(:validate_options_on_save=)

            # Save without validation first
            unless new_question.save(validate: false)
              error_message = "Failed to create question: #{new_question.errors.full_messages.join(', ')}"
              Rails.logger.error(error_message)
              raise ActiveRecord::Rollback, error_message
            end

            # Now duplicate all options
            if original_question.options.any?
              original_question.options.each do |original_option|
                new_option = new_question.options.new(
                  text: original_option.text,
                  value: original_option.value,
                  correct: original_option.correct
                )

                unless new_option.save
                  error_message = "Failed to save option: #{new_option.errors.full_messages.join(', ')}"
                  Rails.logger.error(error_message)
                  raise ActiveRecord::Rollback, error_message
                end
              end
            end

            # Now validate the question with its options
            unless new_question.valid?
              error_message = "Question validation failed after adding options: #{new_question.errors.full_messages.join(', ')}"
              Rails.logger.error(error_message)
              raise ActiveRecord::Rollback, error_message
            end
          else
            # For questions that don't require options, we can create normally
            new_question = current_institute.questions.new(
              title: "Copy of #{original_question.title}",
              description: original_question.description,
              display_name: original_question.display_name ? "Copy of #{original_question.display_name}" : nil,
              question_type: original_question.question_type,
              required: original_question.required,
              active: original_question.active,
              max_rating: original_question.max_rating,
              duration_days: original_question.duration_days,
              from_day: original_question.from_day,
              to_day: original_question.to_day
            )

            unless new_question.save
              error_message = "Failed to save question: #{new_question.errors.full_messages.join(', ')}"
              Rails.logger.error(error_message)
              raise ActiveRecord::Rollback, error_message
            end
          end
        end

        if new_question&.persisted?
          redirect_to institute_admin_questions_path, notice: "Question was successfully duplicated."
        else
          redirect_to institute_admin_questions_path, alert: "Failed to duplicate question. Please try again."
        end
      rescue => e
        Rails.logger.error("Error duplicating question: #{e.message}")
        Rails.logger.error(e.backtrace.join("\n"))
        redirect_to institute_admin_questions_path, alert: "Failed to duplicate question: #{e.message}"
      end
    end

    private

    def set_question
      @question = current_institute.questions.includes(:options).find(params[:id])
    end

    def question_params
      params.require(:question).permit(
        :title,
        :description,
        :display_name,
        :question_type,
        :required,
        :max_rating,
        :position,
        :duration_days,
        :from_day,
        :to_day,
        options_attributes: [ :id, :text, :correct, :_destroy ]
      )
    end

    # Sanitize parameters to ensure no null values for options text
    def sanitize_question_params(params)
      if params[:options_attributes].present?
        params[:options_attributes].each do |key, option_attrs|
          unless option_attrs[:_destroy] == "1"
            option_attrs[:text] = "Option #{Time.now.to_i}" if option_attrs[:text].blank?
          end
        end
      end
      params
    end

    # Ensure all options have text
    def ensure_options_have_text(question)
      question.options.each do |option|
        if option.text.blank? && !option.marked_for_destruction?
          option.text = "Option #{Time.now.to_i}"
        end
      end
    end

    def generate_questions_csv(questions)
      require "csv"
      CSV.generate(headers: true) do |csv|
        csv << [ "#", "Title", "Display Name", "Question Type", "Status", "Required", "Options Count", "Created Date" ]
        questions.each_with_index do |q, idx|
          csv << [
            idx + 1,
            q.title,
            q.display_name.presence || "Not Set",
            q.question_type.titleize,
            q.active? ? "Active" : "Inactive",
            q.required? ? "Yes" : "No",
            q.options.count,
            q.created_at.strftime("%Y-%m-%d %H:%M")
          ]
        end
      end
    end

    def generate_questions_pdf_with_ferrum
      require "ferrum"
      require "base64"

      html_content = render_to_string(
        template: "institute_admin/questions/pdf",
        formats: [ :html ],
        layout: false,
        locals: {
          questions: @questions,
          total_count: @total_questions_count,
          active_count: @active_questions_count,
          types_count: @types_count,
          required_count: @required_questions_count,
          institute: current_institute
        }
      )

      browser = Ferrum::Browser.new(
        timeout: 15,
        window_size: [ 1200, 1600 ],
        browser_options: {
          "no-sandbox": nil,
          "disable-gpu": nil,
          "disable-dev-shm-usage": nil
        }
      )

      begin
        base64_html = Base64.strict_encode64(html_content)
        data_uri = "data:text/html;base64,#{base64_html}"
        browser.go_to(data_uri)
        pdf_data = browser.pdf(
          format: :A4,
          landscape: false,
          print_background: true
        )

        if pdf_data.present? && !pdf_data.start_with?("%PDF")
          pdf_data = Base64.decode64(pdf_data)
        end

        pdf_data
      ensure
        browser.quit
      end
    end
  end
end
