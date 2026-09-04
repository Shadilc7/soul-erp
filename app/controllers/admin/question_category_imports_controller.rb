require "csv"

module Admin
  class QuestionCategoryImportsController < Admin::BaseController
    before_action :set_category
    before_action :set_import, only: [ :show, :status, :failed_rows ]

    def index
      @imports = @category.question_imports.ordered
    end

    def new
      @import = @category.question_imports.build
      @recent_imports = @category.question_imports.ordered.limit(5)
    end

    def create
      @import = @category.question_imports.build(import_params)
      @import.user = current_user

      uploaded_file = params[:file] || params.dig(:question_import, :file)
      if uploaded_file.blank?
        flash.now[:alert] = "Please select a valid CSV file to upload."
        @recent_imports = @category.question_imports.ordered.limit(5)
        render :new, status: :unprocessable_entity
        return
      end

      @import.file.attach(uploaded_file)
      @import.filename = uploaded_file.original_filename
      @import.file_size = uploaded_file.size

      if @import.save
        if @import.dry_run?
          # Synchronous dry-run for immediate feedback
          QuestionImporter.new(@import).process!
          redirect_to admin_question_category_import_path(@category, @import), notice: "Dry-run validation complete. Inspect logs and validation summary below.", status: :see_other
        else
          # Asynchronous processing via background job
          QuestionImportJob.perform_later(@import.id)
          redirect_to admin_question_category_import_path(@category, @import), notice: "Import queued successfully. Monitoring progress and live logs...", status: :see_other
        end
      else
        flash.now[:alert] = @import.errors.full_messages.to_sentence
        @recent_imports = @category.question_imports.ordered.limit(5)
        render :new, status: :unprocessable_entity
      end
    end

    def show
    end

    def status
      render json: {
        id: @import.id,
        status: @import.status,
        status_label: @import.status.titleize,
        total_rows: @import.total_rows,
        successful_rows: @import.successful_rows,
        failed_rows: @import.failed_rows,
        success_rate: @import.success_rate,
        completed: @import.completed_or_failed?,
        process_log: @import.process_log || [],
        error_log: @import.error_log || []
      }
    end

    def sample_template
      max_days = @category.duration_days.presence || 30
      headers = [
        "Question Title / Statement",
        "Display Name (Optional)",
        "From Day",
        "To Day",
        "Description / Instructions (Optional)",
        "Question Type",
        "Required Question",
        "Active Question",
        "Options (Optional, pipe separated)",
        "Max Rating (Optional)"
      ]

      guide_row = [
        "e.g. How are you feeling today?",
        "Daily Mood",
        "1",
        max_days.to_s,
        "Helpful instructions for participant",
        "multiple_choice",
        "Yes",
        "Yes",
        "Option A | Option B | Option C",
        "5"
      ]

      sample_rows = [
        [
          "What was the main accomplishment of your day?",
          "Daily Accomplishment",
          "1",
          max_days.to_s,
          "Write a brief 1-2 sentence reflection.",
          "short_answer",
          "Yes",
          "Yes",
          "",
          ""
        ],
        [
          "How would you rate your overall sleep quality last night?",
          "Sleep Quality",
          "1",
          max_days.to_s,
          "1 star is very poor and 5 stars is excellent.",
          "rating",
          "Yes",
          "Yes",
          "",
          "5"
        ],
        [
          "Did you complete your prescribed morning exercise?",
          "Morning Exercise",
          "1",
          max_days.to_s,
          "",
          "yes_or_no",
          "Yes",
          "Yes",
          "Yes | No",
          ""
        ],
        [
          "Which of the following healthy habits did you practice today?",
          "Habits Practiced",
          "1",
          max_days.to_s,
          "Select all that apply.",
          "checkboxes",
          "No",
          "Yes",
          "30 Min Brisk Walk | 2L Water | Meditation | Reading | Early Bedtime",
          ""
        ],
        [
          "What primary challenge or obstacle did you encounter today?",
          "Primary Challenge",
          "1",
          max_days.to_s,
          "Select the closest match.",
          "dropdown",
          "Yes",
          "Yes",
          "Time Management | Fatigue | Distractions | Unexpected Work | None",
          ""
        ],
        [
          "Share any notes, thoughts, or insights from your daily reading.",
          "Daily Journal",
          "1",
          max_days.to_s,
          "",
          "paragraph",
          "No",
          "Yes",
          "",
          ""
        ]
      ]

      csv_data = "\xEF\xBB\xBF" + CSV.generate(headers: true) do |csv|
        csv << headers
        csv << guide_row
        sample_rows.each { |row| csv << row }
      end

      send_data csv_data,
                filename: "question_import_sample_template_#{@category.name.parameterize}.csv",
                type: "text/csv; charset=utf-8",
                disposition: "attachment"
    end

    def sample_excel_template
      max_days = @category.duration_days.presence || 30
      headers = [
        "Question Title / Statement",
        "Display Name (Optional)",
        "From Day",
        "To Day",
        "Description / Instructions (Optional)",
        "Question Type",
        "Required Question",
        "Active Question",
        "Options (Optional, pipe separated)",
        "Max Rating (Optional)"
      ]

      guide_row = [
        "e.g. How are you feeling today?",
        "Daily Mood",
        "1",
        max_days.to_s,
        "Helpful instructions for participant",
        "multiple_choice",
        "Yes",
        "Yes",
        "Option A | Option B | Option C",
        "5"
      ]

      sample_rows = [
        [
          "What was the main accomplishment of your day?",
          "Daily Accomplishment",
          "1",
          max_days.to_s,
          "Write a brief 1-2 sentence reflection.",
          "short_answer",
          "Yes",
          "Yes",
          "",
          ""
        ],
        [
          "How would you rate your overall sleep quality last night?",
          "Sleep Quality",
          "1",
          max_days.to_s,
          "1 star is very poor and 5 stars is excellent.",
          "rating",
          "Yes",
          "Yes",
          "",
          "5"
        ],
        [
          "Did you complete your prescribed morning exercise?",
          "Morning Exercise",
          "1",
          max_days.to_s,
          "",
          "yes_or_no",
          "Yes",
          "Yes",
          "Yes | No",
          ""
        ],
        [
          "Which of the following healthy habits did you practice today?",
          "Habits Practiced",
          "1",
          max_days.to_s,
          "Select all that apply.",
          "checkboxes",
          "No",
          "Yes",
          "30 Min Brisk Walk | 2L Water | Meditation | Reading | Early Bedtime",
          ""
        ],
        [
          "What primary challenge or obstacle did you encounter today?",
          "Primary Challenge",
          "1",
          max_days.to_s,
          "Select the closest match.",
          "dropdown",
          "Yes",
          "Yes",
          "Time Management | Fatigue | Distractions | Unexpected Work | None",
          ""
        ]
      ]

      xml = String.new
      xml << %{<?xml version="1.0"?>\n}
      xml << %{<?mso-application progid="Excel.Sheet"?>\n}
      xml << %{<Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet"\n}
      xml << %{ xmlns:o="urn:schemas-microsoft-com:office:office"\n}
      xml << %{ xmlns:x="urn:schemas-microsoft-com:office:excel"\n}
      xml << %{ xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet"\n}
      xml << %{ xmlns:html="http://www.w3.org/TR/REC-html40">\n}
      xml << %{ <Styles>\n}
      xml << %{  <Style ss:ID="Header">\n}
      xml << %{   <Font ss:Bold="1" ss:Color="#FFFFFF"/>\n}
      xml << %{   <Interior ss:Color="#1E293B" ss:Pattern="Solid"/>\n}
      xml << %{   <Alignment ss:Vertical="Center" ss:WrapText="1"/>\n}
      xml << %{  </Style>\n}
      xml << %{  <Style ss:ID="Guide">\n}
      xml << %{   <Font ss:Italic="1" ss:Color="#64748B"/>\n}
      xml << %{   <Interior ss:Color="#F1F5F9" ss:Pattern="Solid"/>\n}
      xml << %{  </Style>\n}
      xml << %{ </Styles>\n}
      xml << %{ <Worksheet ss:Name="Questions">\n}
      xml << %{  <Table>\n}
      xml << %{   <Column ss:Width="250"/>\n}
      xml << %{   <Column ss:Width="140"/>\n}
      xml << %{   <Column ss:Width="80"/>\n}
      xml << %{   <Column ss:Width="80"/>\n}
      xml << %{   <Column ss:Width="220"/>\n}
      xml << %{   <Column ss:Width="120"/>\n}
      xml << %{   <Column ss:Width="80"/>\n}
      xml << %{   <Column ss:Width="80"/>\n}
      xml << %{   <Column ss:Width="250"/>\n}
      xml << %{   <Column ss:Width="90"/>\n}

      xml << %{   <Row ss:Height="26" ss:StyleID="Header">\n}
      headers.each do |h|
        xml << %{    <Cell><Data ss:Type="String">#{CGI.escapeHTML(h)}</Data></Cell>\n}
      end
      xml << %{   </Row>\n}

      xml << %{   <Row ss:StyleID="Guide">\n}
      guide_row.each do |val|
        xml << %{    <Cell><Data ss:Type="String">#{CGI.escapeHTML(val)}</Data></Cell>\n}
      end
      xml << %{   </Row>\n}

      sample_rows.each do |row|
        xml << %{   <Row>\n}
        row.each do |val|
          xml << %{    <Cell><Data ss:Type="String">#{CGI.escapeHTML(val)}</Data></Cell>\n}
        end
        xml << %{   </Row>\n}
      end

      xml << %{  </Table>\n}
      xml << %{ </Worksheet>\n}
      xml << %{</Workbook>\n}

      send_data xml,
                filename: "question_import_sample_template_#{@category.name.parameterize}.xls",
                type: "application/vnd.ms-excel; charset=utf-8",
                disposition: "attachment"
    end

    def blank_template
      headers = [
        "Question Title / Statement",
        "Display Name (Optional)",
        "From Day",
        "To Day",
        "Description / Instructions (Optional)",
        "Question Type",
        "Required Question",
        "Active Question",
        "Options (Optional, pipe separated)",
        "Max Rating (Optional)"
      ]

      csv_data = "\xEF\xBB\xBF" + CSV.generate(headers: true) do |csv|
        csv << headers
      end

      send_data csv_data,
                filename: "question_import_blank_template_#{@category.name.parameterize}.csv",
                type: "text/csv; charset=utf-8",
                disposition: "attachment"
    end

    def blank_excel_template
      headers = [
        "Question Title / Statement",
        "Display Name (Optional)",
        "From Day",
        "To Day",
        "Description / Instructions (Optional)",
        "Question Type",
        "Required Question",
        "Active Question",
        "Options (Optional, pipe separated)",
        "Max Rating (Optional)"
      ]

      xml = String.new
      xml << %{<?xml version="1.0"?>\n}
      xml << %{<?mso-application progid="Excel.Sheet"?>\n}
      xml << %{<Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet"\n}
      xml << %{ xmlns:o="urn:schemas-microsoft-com:office:office"\n}
      xml << %{ xmlns:x="urn:schemas-microsoft-com:office:excel"\n}
      xml << %{ xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet"\n}
      xml << %{ xmlns:html="http://www.w3.org/TR/REC-html40">\n}
      xml << %{ <Styles>\n}
      xml << %{  <Style ss:ID="Header">\n}
      xml << %{   <Font ss:Bold="1" ss:Color="#FFFFFF"/>\n}
      xml << %{   <Interior ss:Color="#1E293B" ss:Pattern="Solid"/>\n}
      xml << %{   <Alignment ss:Vertical="Center" ss:WrapText="1"/>\n}
      xml << %{  </Style>\n}
      xml << %{ </Styles>\n}
      xml << %{ <Worksheet ss:Name="Questions">\n}
      xml << %{  <Table>\n}
      xml << %{   <Column ss:Width="250"/>\n}
      xml << %{   <Column ss:Width="140"/>\n}
      xml << %{   <Column ss:Width="80"/>\n}
      xml << %{   <Column ss:Width="80"/>\n}
      xml << %{   <Column ss:Width="220"/>\n}
      xml << %{   <Column ss:Width="120"/>\n}
      xml << %{   <Column ss:Width="80"/>\n}
      xml << %{   <Column ss:Width="80"/>\n}
      xml << %{   <Column ss:Width="250"/>\n}
      xml << %{   <Column ss:Width="90"/>\n}

      xml << %{   <Row ss:Height="26" ss:StyleID="Header">\n}
      headers.each do |h|
        xml << %{    <Cell><Data ss:Type="String">#{CGI.escapeHTML(h)}</Data></Cell>\n}
      end
      xml << %{   </Row>\n}
      xml << %{  </Table>\n}
      xml << %{ </Worksheet>\n}
      xml << %{</Workbook>\n}

      send_data xml,
                filename: "question_import_blank_template_#{@category.name.parameterize}.xls",
                type: "application/vnd.ms-excel; charset=utf-8",
                disposition: "attachment"
    end

    def failed_rows
      error_records = @import.error_log || []
      if error_records.empty?
        redirect_to admin_question_category_import_path(@category, @import), alert: "No failed rows found for this import."
        return
      end

      headers = [
        "Row Number",
        "Question Title / Statement",
        "Display Name (Optional)",
        "From Day",
        "To Day",
        "Description / Instructions (Optional)",
        "Question Type",
        "Required Question",
        "Active Question",
        "Options (Optional, pipe separated)",
        "Max Rating (Optional)",
        "Error Reasons"
      ]

      csv_data = "\xEF\xBB\xBF" + CSV.generate(headers: true) do |csv|
        csv << headers
        error_records.each do |rec|
          raw = rec["raw_data"] || {}
          csv << [
            rec["row"],
            raw["Question Title / Statement"] || raw["title"] || rec["title"],
            raw["Display Name (Optional)"] || raw["display_name"],
            raw["From Day"] || raw["from_day"],
            raw["To Day"] || raw["to_day"],
            raw["Description / Instructions (Optional)"] || raw["description"],
            raw["Question Type"] || raw["question_type"],
            raw["Required Question"] || raw["required"],
            raw["Active Question"] || raw["active"],
            raw["Options (Optional, pipe separated)"] || raw["options"],
            raw["Max Rating (Optional)"] || raw["max_rating"],
            (rec["errors"] || []).join(" | ")
          ]
        end
      end

      send_data csv_data,
                filename: "failed_rows_import_#{@import.id}.csv",
                type: "text/csv; charset=utf-8",
                disposition: "attachment"
    end

    private

    def set_category
      @category = QuestionCategory.master.includes(:question_bank).find(params[:question_category_id])
    end

    def set_import
      @import = @category.question_imports.find(params[:id])
    end

    def import_params
      if params[:question_import].present?
        params.require(:question_import).permit(:dry_run, :rollback_on_error)
      else
        {}
      end
    end
  end
end
