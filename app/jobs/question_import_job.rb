class QuestionImportJob < ApplicationJob
  queue_as :default

  def perform(question_import_id)
    question_import = QuestionImport.find_by(id: question_import_id)
    return unless question_import.present?

    QuestionImporter.new(question_import).process!
  rescue => e
    Rails.logger.error("QuestionImportJob failed: #{e.message}\n#{e.backtrace.join("\n")}")
    if question_import.present?
      logs = (question_import.process_log || []).dup
      logs << {
        "time" => Time.current.strftime("%H:%M:%S"),
        "level" => "error",
        "message" => "Background job crashed: #{e.message}"
      }
      question_import.update_columns(
        status: QuestionImport.statuses["failed"],
        process_log: logs,
        updated_at: Time.current
      )
    end
  end
end
