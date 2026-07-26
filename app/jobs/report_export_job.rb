class ReportExportJob < ApplicationJob
  queue_as :default

  def perform(export_token, report_type, params_hash, institute_id)
    institute = Institute.find(institute_id)

    # Stage 1: Enqueued & Fetching Filters (15%)
    update_progress(export_token, "processing", 15, "Fetching report filters & records...")

    controller = InstituteAdmin::ReportsController.new
    controller.params = ActionController::Parameters.new(params_hash)
    controller.instance_variable_set(:@current_institute, institute)
    controller.define_singleton_method(:current_institute) { institute }

    # Stage 2: Data Aggregation & Calculations (40%)
    controller.send(:fetch_individual_assignment_reports)
    report_rows = controller.instance_variable_get(:@report_rows) || []
    total_rows = [ report_rows.size, 1 ].max

    update_progress(export_token, "processing", 40, "Aggregated #{total_rows} report records...")

    # Stage 3: Rendering PDF or Formatting CSV (70%)
    if report_type == "individual_assignment_pdf"
      update_progress(export_token, "processing", 70, "Rendering PDF layout with Ferrum...")
      file_data = controller.send(:generate_individual_assignment_pdf_with_ferrum)
      content_type = "application/pdf"
      filename = "individual_assignment_report_#{Date.current.strftime('%Y%m%d')}.pdf"
    else
      update_progress(export_token, "processing", 75, "Formatting CSV spreadsheet output...")
      file_data = controller.send(:generate_individual_assignment_csv)
      content_type = "text/csv"
      filename = "individual_assignment_report_#{Date.current.strftime('%Y%m%d')}.csv"
    end

    # Stage 4: Finalizing & Packaging (92%)
    update_progress(export_token, "processing", 92, "Finalizing download package...")
    Rails.cache.write("export_file_#{export_token}", { data: file_data, content_type: content_type, filename: filename }, expires_in: 30.minutes)

    # Stage 5: Completed (100%)
    update_progress(export_token, "completed", 100, "Export ready for download!")
  rescue StandardError => e
    Rails.logger.error("ReportExportJob failed: #{e.message}\n#{e.backtrace.join("\n")}")
    update_progress(export_token, "failed", 0, "Export failed: #{e.message}")
  end

  private

  def update_progress(token, status, progress, message)
    Rails.cache.write("export_progress_#{token}", { status: status, progress: progress, message: message }, expires_in: 30.minutes)
  end
end
