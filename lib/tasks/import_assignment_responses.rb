# =============================================================================
# Bulk Assignment Response Import Script
# Usage (Rails console):
#   load 'lib/tasks/import_assignment_responses.rb'
#   BulkAssignmentResponseImport.run('tmp/responses.csv', institute_id: 1)
#
# CSV columns (tab or comma separated):
#   Student Name | Student Email Id | student mobile number |
#   Date of submission (dd/mm/yyyy or dd/mm/yyyy HH:MM:SS) |
#   Assignment Title | <Question Title 1> | <Question Title 2> | ...
#
# Notes:
#   - Question columns are matched to Question records by title (case-insensitive).
#   - Rows already submitted for that date are skipped.
#   - Creates both AssignmentResponse and AssignmentResponseLog records,
#     exactly as the participant portal submit action does.
# =============================================================================

require "csv"

module BulkAssignmentResponseImport
  FIXED_COLUMNS = [
    "student name",
    "student email id",
    "student mobile number",
    "date of submission(dd-mm-yyyy format)",
    "assignment title"
  ].freeze

  # ---------------------------------------------------------------------------
  def self.detect_separator(file_path)
    first_line = File.open(file_path, "r:bom|utf-8", &:readline)
    first_line.count("\t") >= first_line.count(",") ? "\t" : ","
  end

  # ---------------------------------------------------------------------------
  def self.run(csv_path, institute_id:, dry_run: false, assignment_title: nil)
    raise "File not found: #{csv_path}" unless File.exist?(csv_path)

    institute = Institute.find(institute_id)
    sep       = detect_separator(csv_path)

    rows = CSV.read(csv_path, headers: true, col_sep: sep,
                              encoding: "bom|utf-8")
    # Normalize headers: strip whitespace, downcase for matching
    rows.headers  # trigger parse

    results = { created: 0, skipped: 0, failed: [] }

    # ---- Identify question columns (all headers after the 5 fixed ones) ----
    # Use original headers from the file, normalise for matching
    raw_headers       = rows.headers.map { |h| h.to_s.strip }
    question_headers  = raw_headers.reject { |h| FIXED_COLUMNS.include?(h.downcase) }
                                   .reject(&:blank?)

    # ---- Resolve assignment once for the entire file ---------------------
    title_to_find = assignment_title || rows.first&.[]( "Assignment Title")&.strip
    raise "Assignment title not found in CSV and not provided" if title_to_find.blank?

    assignment = Assignment.where(institute: institute)
                           .find_by("LOWER(title) = ?", title_to_find.downcase)
    raise "Assignment '#{title_to_find}' not found in institute #{institute.name}" unless assignment

    puts "\n#{"=" * 70}"
    puts "Institute  : #{institute.name}"
    puts "Assignment : #{assignment.title}"
    puts "Total rows : #{rows.size}"
    puts "Question columns detected (#{question_headers.size}): #{question_headers.join(' | ')}"
    puts "Dry run    : #{dry_run}"
    puts "=" * 70

    rows.each_with_index do |row, idx|
      line_no = idx + 2

      # ---- Parse fixed fields ----------------------------------------------
      email    = row["Student Email Id"]&.strip&.downcase
      date_raw = row["Date of submission(dd-mm-yyyy format)"]&.strip ||
                 row.fields.find { |f| f.to_s =~ /\d{2}[\/\-]\d{2}[\/\-]\d{4}/ }

      if email.blank?
        results[:failed] << { line: line_no, reason: "Missing email" }
        next
      end

      # ---- Parse submission date -------------------------------------------
      response_date = begin
        # Accept "01/11/2024 21:12:35", "01/11/2024", "01-11-2024", etc.
        cleaned = date_raw.to_s.strip.split(" ").first  # take date part only
        cleaned = cleaned.gsub("-", "/")
        Date.strptime(cleaned, "%d/%m/%Y")
      rescue ArgumentError, TypeError
        results[:failed] << { line: line_no, email: email, reason: "Cannot parse date: '#{date_raw}'" }
        next
      end

      # ---- Resolve participant ---------------------------------------------
      user = User.find_by(email: email)
      unless user&.participant
        results[:failed] << { line: line_no, email: email, reason: "Participant not found" }
        next
      end
      participant = user.participant

      # ---- Skip if already submitted --------------------------------------
      if assignment.answered_by_on_date?(participant, response_date)
        puts "  SKIP  Line #{line_no} #{email} – already submitted for #{response_date}"
        results[:skipped] += 1
        next
      end

      # ---- Match question columns to Question records ---------------------
      question_map = {}   # { question_id => answer_string }

      question_headers.each do |col|
        answer = row[col].to_s.strip
        next if answer.blank? && !row.field?(col)

        question = assignment.questions.find do |q|
          q.title.downcase.strip == col.downcase.strip
        end

        unless question
          # Try a broader search: any question in the institute whose title matches
          question = Question.joins(:assignment_questions)
                             .where(assignment_questions: { assignment_id: assignment.id })
                             .find_by("LOWER(title) = ?", col.downcase.strip)
        end

        if question
          question_map[question.id] = { question: question, answer: answer }
        else
          puts "  WARN  Line #{line_no} – no question matches column '#{col}' – skipping column"
        end
      end

      if question_map.empty?
        results[:failed] << { line: line_no, email: email, reason: "No matching questions found" }
        next
      end

      if dry_run
        puts "[DRY RUN] Line #{line_no}: #{email} | #{assignment_title} | #{response_date} | #{question_map.size} responses"
        results[:created] += 1
        next
      end

      # ---- Save responses -------------------------------------------------
      begin
        ActiveRecord::Base.transaction do
          saved_response_ids = []

          question_map.each do |question_id, data|
            question = data[:question]
            answer   = data[:answer]

            response = participant.assignment_responses.find_or_initialize_by(
              assignment: assignment,
              question_id: question_id,
              response_date: response_date
            )

            # Mirror the submit action's type handling
            case question.question_type
            when "checkboxes"
              response.selected_options = answer.split(",").map(&:strip)
              response.answer = response.selected_options.join(", ")
            when "multiple_choice", "dropdown", "rating"
              response.answer = answer
              response.selected_options = [answer].compact
            when "yes_or_no"
              # Normalise to "Yes" / "No"
              response.answer = answer.downcase.start_with?("y") ? "Yes" : "No"
              response.selected_options = []
            when "number"
              response.answer = answer.present? ? answer.to_s : "0"
              response.selected_options = []
            else
              # short_answer, paragraph, date, time, etc.
              response.answer = answer
              response.selected_options = []
            end

            response.submitted_at = Time.current

            unless response.save
              raise ActiveRecord::Rollback,
                    "Failed to save response for question '#{question.title}': #{response.errors.full_messages.join(', ')}"
            end

            saved_response_ids << response.id
          end

          AssignmentResponseLog.log_responses(
            participant: participant,
            assignment: assignment,
            response_ids: saved_response_ids,
            response_date: response_date
          )

          results[:created] += 1
          print "."
        end
      rescue => e
        results[:failed] << { line: line_no, email: email, reason: e.message }
      end
    end

    # ---- Summary -----------------------------------------------------------
    puts "\n\n#{"=" * 70}"
    puts "RESULTS"
    puts "  Created : #{results[:created]}"
    puts "  Skipped : #{results[:skipped]}"
    puts "  Failed  : #{results[:failed].size}"

    if results[:failed].any?
      puts "\nFailed rows:"
      results[:failed].each { |f| puts "  Line #{f[:line]} – #{f[:email] || '?'} – #{f[:reason]}" }
    end

    puts "=" * 70
    results
  end
end
