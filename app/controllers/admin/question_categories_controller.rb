module Admin
  class QuestionCategoriesController < Admin::BaseController
    before_action :set_category, only: [ :show, :edit, :update, :destroy, :builder ]

    def index
      @question_banks = QuestionBank.ordered
      @categories = QuestionCategory.includes(:question_bank).ordered

      if params[:question_bank_id].present?
        @selected_bank = QuestionBank.find_by(id: params[:question_bank_id])
        @categories = @categories.where(question_bank_id: params[:question_bank_id])
      end

      if params[:search].present?
        query = "%#{params[:search].downcase}%"
        @categories = @categories.where("LOWER(name) LIKE :q OR LOWER(description) LIKE :q", q: query)
      end

      category_ids = @categories.pluck(:id)
      @total_categories_count = category_ids.size
      @active_categories_count = @categories.where(active: true).count
      @total_questions_count = Question.where(question_category_id: category_ids).count
      @total_bundles_count = QuestionBundle.where(question_category_id: category_ids).count

      @questions_count_by_category_id = Question.where(question_category_id: category_ids).group(:question_category_id).count
      @bundles_count_by_category_id = QuestionBundle.where(question_category_id: category_ids).group(:question_category_id).count
    end

    def show
      redirect_to builder_admin_question_category_path(@category)
    end

    def new
      @category = QuestionCategory.new(
        question_bank_id: params[:question_bank_id] || QuestionBank.first&.id,
        duration_days: 30
      )
    end

    def create
      @category = QuestionCategory.new(category_params)

      if @category.save
        redirect_to builder_admin_question_category_path(@category), notice: "Question Category created successfully. You can now add questions and build bundles."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @category.update(category_params)
        redirect_to builder_admin_question_category_path(@category), notice: "Question Category updated successfully."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      if @category.destroy
        redirect_to admin_question_categories_path, notice: "Question Category was successfully deleted."
      else
        redirect_to admin_question_categories_path, alert: @category.errors.full_messages.to_sentence
      end
    end

    def builder
      @questions = @category.questions.includes(:question_bundles).order(position: :asc, created_at: :desc)
      @bundles = @category.question_bundles.includes(:question_bundle_items).ordered
      @new_question = @category.questions.build(duration_days: 1)
      @new_bundle = @category.question_bundles.build
    end

    private

    def set_category
      @category = QuestionCategory.find(params[:id])
    end

    def category_params
      params.require(:question_category).permit(:question_bank_id, :name, :description, :duration_days, :active)
    end
  end
end
