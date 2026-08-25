module Admin
  class QuestionBundlesController < Admin::BaseController
    before_action :set_category
    before_action :set_bundle, only: [ :edit, :update, :destroy, :add_question, :remove_question, :reorder_questions ]

    def create
      @bundle = @category.question_bundles.build(bundle_params)

      if @bundle.save
        respond_to do |format|
          format.html { redirect_to builder_admin_question_category_path(@category), notice: "Bundle created successfully." }
          format.json { render json: { status: "success", bundle: @bundle } }
        end
      else
        respond_to do |format|
          format.html { redirect_to builder_admin_question_category_path(@category), alert: @bundle.errors.full_messages.to_sentence }
          format.json { render json: { status: "error", errors: @bundle.errors.full_messages }, status: :unprocessable_entity }
        end
      end
    end

    def edit
    end

    def update
      if @bundle.update(bundle_params)
        redirect_to builder_admin_question_category_path(@category), notice: "Bundle updated successfully."
      else
        redirect_to builder_admin_question_category_path(@category), alert: @bundle.errors.full_messages.to_sentence
      end
    end

    def destroy
      @bundle.destroy
      redirect_to builder_admin_question_category_path(@category), notice: "Bundle deleted successfully."
    end

    def add_question
      @question = @category.questions.find(params[:question_id])
      existing_item = @bundle.question_bundle_items.find_by(question_id: @question.id)

      if existing_item
        render_already_added_warning
        return
      end

      @item = @bundle.question_bundle_items.build(question: @question)
      @item.position = (@bundle.question_bundle_items.maximum(:position) || 0) + 1

      if @item.save
        respond_to do |format|
          format.turbo_stream
          format.json {
            render json: {
              status: "success",
              message: "Question added to #{@bundle.name}",
              bundle_id: @bundle.id,
              question_id: @question.id,
              bundle_questions_count: @bundle.questions.count
            }
          }
        end
      else
        render_already_added_warning(@item.errors.full_messages.to_sentence)
      end
    rescue ActiveRecord::RecordNotFound
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.append("toast-container", partial: "admin/question_bundles/toast", formats: [:html], locals: { message: "Question not found", type: "danger" }) }
        format.json { render json: { status: "error", message: "Question not found" }, status: :not_found }
      end
    rescue ActiveRecord::RecordNotUnique
      render_already_added_warning
    end

    def remove_question
      @item = @bundle.question_bundle_items.find_by(question_id: params[:question_id])
      @question_id = params[:question_id]
      @question = @category.questions.find_by(id: @question_id)

      if @item&.destroy
        respond_to do |format|
          format.turbo_stream
          format.json {
            render json: {
              status: "success",
              message: "Question removed from #{@bundle.name}",
              bundle_id: @bundle.id,
              question_id: @question_id,
              bundle_questions_count: @bundle.questions.count
            }
          }
        end
      else
        respond_to do |format|
          format.turbo_stream { render turbo_stream: turbo_stream.append("toast-container", partial: "admin/question_bundles/toast", formats: [:html], locals: { message: "Question item not found", type: "danger" }) }
          format.json { render json: { status: "error", message: "Question item not found" }, status: :not_found }
        end
      end
    end

    def reorder_questions
      if params[:question_ids].is_a?(Array)
        params[:question_ids].each_with_index do |q_id, idx|
          @bundle.question_bundle_items.where(question_id: q_id).update_all(position: idx + 1)
        end
      end
      render json: { status: "success", message: "Questions reordered successfully" }
    end

    private

    def set_category
      @category = QuestionCategory.master.find(params[:question_category_id])
    end

    def set_bundle
      @bundle = @category.question_bundles.find(params[:id] || params[:bundle_id])
    end

    def bundle_params
      params.require(:question_bundle).permit(:name, :description, :position, :from_day, :to_day)
    end

    def render_already_added_warning(msg = nil)
      @message = msg.presence || "Question already added to #{@bundle&.name || 'bundle'}"
      respond_to do |format|
        format.turbo_stream {
          render turbo_stream: turbo_stream.append("toast-container", partial: "admin/question_bundles/toast", formats: [:html], locals: { message: @message, type: "warning" })
        }
        format.json {
          render json: { status: "warning", message: @message }, status: :ok
        }
      end
    end
  end
end
