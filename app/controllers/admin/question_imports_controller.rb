module Admin
  class QuestionImportsController < Admin::BaseController
    def index
      @question_banks = QuestionBank.ordered
      @categories = QuestionCategory.master.includes(:question_bank).ordered
      @imports = QuestionImport.includes(:user, question_category: :question_bank).ordered

      if params[:question_bank_id].present?
        @categories = @categories.where(question_bank_id: params[:question_bank_id])
        bank_cat_ids = @categories.pluck(:id)
        @imports = @imports.where(question_category_id: bank_cat_ids)
      end

      if params[:question_category_id].present?
        @selected_category = QuestionCategory.master.find_by(id: params[:question_category_id])
        @imports = @imports.where(question_category_id: params[:question_category_id]) if @selected_category
      end

      if params[:status].present? && QuestionImport.statuses.key?(params[:status])
        @imports = @imports.where(status: params[:status])
      end

      # Separate live imports from dry runs
      @live_imports = @imports.actual
      @dry_run_imports = @imports.dry_runs

      # Separate KPI metrics: live DB creations vs dry-run simulations
      @total_live_imports_count = QuestionImport.actual.count
      @total_live_questions_count = QuestionImport.actual.sum(:successful_rows)
      @total_dry_runs_count = QuestionImport.dry_runs.count
      @total_failed_count = QuestionImport.where(status: [ :failed, :partially_completed ]).count

      # View mode: "all" (both separated), "live" (live imports only), "dry_run" (dry runs only)
      @view_mode = params[:mode].presence || "all"
    end

    def show
      @import = QuestionImport.find(params[:id])
      redirect_to admin_question_category_import_path(@import.question_category, @import)
    end
  end
end
