module Admin
  class QuestionBanksController < BaseController
    before_action :set_question_bank, only: [ :show, :edit, :update, :destroy ]

    def index
      @question_banks = QuestionBank.ordered

      if params[:search].present?
        query = "%#{params[:search].downcase}%"
        @question_banks = @question_banks.where("LOWER(name) LIKE :q OR LOWER(description) LIKE :q", q: query)
      end

      # KPI Summary & Pre-grouped counts
      bank_ids = @question_banks.pluck(:id)
      @total_banks_count = @question_banks.count
      @active_banks_count = @question_banks.where(active: true).count
      @total_categories_count = QuestionCategory.master.where(question_bank_id: bank_ids).count
      @categories_count_by_bank_id = QuestionCategory.master.where(question_bank_id: bank_ids).group(:question_bank_id).count
    end

    def show
      redirect_to admin_question_categories_path(question_bank_id: @question_bank.id)
    end

    def new
      @question_bank = QuestionBank.new
    end

    def create
      @question_bank = QuestionBank.new(question_bank_params)

      if @question_bank.save
        redirect_to admin_question_banks_path, notice: "Question Bank '#{@question_bank.name}' was successfully created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @question_bank.update(question_bank_params)
        redirect_to admin_question_banks_path, notice: "Question Bank '#{@question_bank.name}' was successfully updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      name = @question_bank.name
      if @question_bank.destroy
        redirect_to admin_question_banks_path, notice: "Question Bank '#{name}' was deleted.", status: :see_other
      else
        error_msg = @question_bank.errors.full_messages.to_sentence.presence || "Cannot delete Question Bank '#{name}' because it contains categories in use by assignments."
        redirect_to admin_question_banks_path, alert: error_msg, status: :see_other
      end
    end

    private

    def set_question_bank
      @question_bank = QuestionBank.find(params[:id])
    end

    def question_bank_params
      params.require(:question_bank).permit(:name, :description, :active)
    end
  end
end
