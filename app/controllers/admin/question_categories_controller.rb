module Admin
  class QuestionCategoriesController < Admin::BaseController
    before_action :set_category, only: [ :show, :edit, :update, :destroy, :builder ]

    def index
      @categories = QuestionCategory.ordered

      if params[:search].present?
        query = "%#{params[:search].downcase}%"
        @categories = @categories.where("LOWER(name) LIKE :q OR LOWER(description) LIKE :q", q: query)
      end

      # KPI Summary
      @total_categories_count = @categories.count
      @active_categories_count = @categories.where(active: true).count
      @total_questions_count = Question.where(question_category_id: @categories.pluck(:id)).count
      @total_bundles_count = QuestionBundle.where(question_category_id: @categories.pluck(:id)).count
    end

    def show
      redirect_to builder_admin_question_category_path(@category)
    end

    def new
      @category = QuestionCategory.new(
        start_date: Date.current,
        end_date: Date.current + 30.days
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
      @questions = @category.questions.includes(:options, :question_bundles).order(position: :asc, created_at: :desc)
      @bundles = @category.question_bundles.includes(:question_bundle_items).ordered
      @new_question = @category.questions.build
      @new_bundle = @category.question_bundles.build
    end

    private

    def set_category
      @category = QuestionCategory.find(params[:id])
    end

    def category_params
      params.require(:question_category).permit(:name, :description, :start_date, :end_date, :active)
    end
  end
end
