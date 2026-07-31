module Admin
  class CategoryQuestionsController < Admin::BaseController
    before_action :set_category
    before_action :set_question, only: [ :edit, :update, :destroy, :duplicate ]

    def new
      @question = @category.questions.build
    end

    def create
      begin
        question_parameters = sanitize_question_params(question_params)
        @question = @category.questions.build(question_parameters)

        ensure_options_have_text(@question) if @question.requires_options?

        if @question.save
          respond_to do |format|
            format.html { redirect_to builder_admin_question_category_path(@category), notice: "Question added successfully.", status: :see_other }
            format.turbo_stream { redirect_to builder_admin_question_category_path(@category), notice: "Question added successfully.", status: :see_other }
          end
        else
          render :new, status: :unprocessable_entity
        end
      rescue => e
        Rails.logger.error("Error creating question: #{e.message}\n#{e.backtrace.join("\n")}")
        flash.now[:alert] = "Error creating question: #{e.message}"
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      begin
        question_parameters = sanitize_question_params(question_params)
        @question.assign_attributes(question_parameters)

        ensure_options_have_text(@question) if @question.requires_options?

        if @question.save
          respond_to do |format|
            format.html { redirect_to builder_admin_question_category_path(@category), notice: "Question updated successfully.", status: :see_other }
            format.turbo_stream { redirect_to builder_admin_question_category_path(@category), notice: "Question updated successfully.", status: :see_other }
          end
        else
          render :edit, status: :unprocessable_entity
        end
      rescue => e
        Rails.logger.error("Error updating question: #{e.message}\n#{e.backtrace.join("\n")}")
        flash.now[:alert] = "Error updating question: #{e.message}"
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      if @question.destroy
        respond_to do |format|
          format.html { redirect_to builder_admin_question_category_path(@category), notice: "Question deleted successfully.", status: :see_other }
          format.turbo_stream { redirect_to builder_admin_question_category_path(@category), notice: "Question deleted successfully.", status: :see_other }
        end
      else
        redirect_to builder_admin_question_category_path(@category), alert: @question.errors.full_messages.to_sentence, status: :see_other
      end
    end

    def reorder
      if params[:question_ids].is_a?(Array)
        params[:question_ids].each_with_index do |q_id, idx|
          @category.questions.where(id: q_id).update_all(position: idx + 1)
        end
      end
      render json: { status: "success", message: "Questions reordered successfully" }
    end

    def duplicate
      new_question = @question.dup
      new_question.title = "Copy of #{@question.title}"
      new_question.validate_options_on_save = false if new_question.respond_to?(:validate_options_on_save=)

      ActiveRecord::Base.transaction do
        new_question.save!(validate: false)
        @question.options.each do |opt|
          new_question.options.create!(text: opt.text, value: opt.value, correct: opt.correct)
        end
      end

      redirect_to builder_admin_question_category_path(@category), notice: "Question duplicated successfully."
    rescue => e
      redirect_to builder_admin_question_category_path(@category), alert: "Failed to duplicate question: #{e.message}"
    end

    private

    def set_category
      @category = QuestionCategory.find(params[:question_category_id])
    end

    def set_question
      @question = @category.questions.includes(:options).find(params[:id])
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
        :active,
        :duration_days,
        options_attributes: [ :id, :text, :value, :correct, :_destroy ]
      )
    end

    def sanitize_question_params(params)
      if params[:options_attributes].present?
        params[:options_attributes].each do |_key, option_attrs|
          unless option_attrs[:_destroy] == "1"
            option_attrs[:text] = "Option #{Time.now.to_i}" if option_attrs[:text].blank?
          end
        end
      end
      params
    end

    def ensure_options_have_text(question)
      question.options.each do |option|
        if option.text.blank? && !option.marked_for_destruction?
          option.text = "Option #{Time.now.to_i}"
        end
      end
    end
  end
end
