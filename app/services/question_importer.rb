require "csv"

class QuestionImporter
  TYPE_MAPPINGS = {
    "short_answer" => :short_answer,
    "short answer" => :short_answer,
    "text" => :short_answer,
    "string" => :short_answer,
    "paragraph" => :paragraph,
    "long_answer" => :paragraph,
    "long answer" => :paragraph,
    "essay" => :paragraph,
    "textarea" => :paragraph,
    "multiple_choice" => :multiple_choice,
    "multiple choice" => :multiple_choice,
    "single_choice" => :multiple_choice,
    "single choice" => :multiple_choice,
    "radio" => :multiple_choice,
    "radio button" => :multiple_choice,
    "radio buttons" => :multiple_choice,
    "checkboxes" => :checkboxes,
    "checkbox" => :checkboxes,
    "check box" => :checkboxes,
    "check_box" => :checkboxes,
    "multi_select" => :checkboxes,
    "multi select" => :checkboxes,
    "multi-select" => :checkboxes,
    "multi_choice" => :checkboxes,
    "multi-choice" => :checkboxes,
    "dropdown" => :dropdown,
    "select" => :dropdown,
    "drop down" => :dropdown,
    "date" => :date,
    "datepicker" => :date,
    "time" => :time,
    "timepicker" => :time,
    "rating" => :rating,
    "star_rating" => :rating,
    "star rating" => :rating,
    "star" => :rating,
    "stars" => :rating,
    "number" => :number,
    "numeric" => :number,
    "integer" => :number,
    "yes_or_no" => :yes_or_no,
    "yes or no" => :yes_or_no,
    "yes / no" => :yes_or_no,
    "yes/no" => :yes_or_no,
    "true/false" => :yes_or_no,
    "true / false" => :yes_or_no,
    "boolean" => :yes_or_no
  }.freeze

  attr_reader :question_import, :category, :logs, :errors_list, :created_question_ids

  def initialize(question_import)
    @question_import = question_import
    @category = question_import.question_category
    @logs = (@question_import.process_log || []).dup
    @errors_list = (@question_import.error_log || []).dup
    @created_question_ids = []
  end

  def process!
    question_import.update!(status: :processing)
    log_event("info", "Starting question import for category '#{category.name}' (Category duration: #{category.duration_days} days).")

    unless question_import.file.attached?
      log_event("error", "No file attached to import.")
      finalize_import!(:failed, 0, 0, 0)
      return false
    end

    raw_data = question_import.file.download
    filename = question_import.file.filename.to_s

    headers, parsed_rows = parse_file_data(raw_data, filename)

    if headers.blank?
      log_event("error", "File structure error: unable to parse valid spreadsheet data from '#{filename}'.")
      @errors_list << {
        row: 1,
        title: "File Structure Error",
        errors: ["Invalid or unsupported file format. Please upload a valid CSV (.csv) or Excel (.xls, .xlsx) file."],
        raw_data: {}
      }
      finalize_import!(:failed, 0, 0, 0)
      return false
    end

    header_map = map_headers(headers)

    unless header_map[:title].present? && header_map[:question_type].present?
      missing = []
      missing << "Question Title / Statement" unless header_map[:title].present?
      missing << "Question Type" unless header_map[:question_type].present?

      msg = "Missing required column headers: #{missing.join(', ')}."
      log_event("error", msg)
      @errors_list << {
        row: 1,
        title: "Header Error",
        errors: [msg, "Detected headers: #{headers.join(', ')}"],
        raw_data: {}
      }
      finalize_import!(:failed, 0, 0, 0)
      return false
    end

    log_event("info", "Headers validated successfully (#{parsed_rows.size} total rows read).")

    # Filter out blank rows and instruction rows
    data_rows = []
    parsed_rows.each_with_index do |row, idx|
      row_num = idx + 2 # Header is row 1
      if instruction_or_empty_row?(row, header_map)
        log_event("info", "Row #{row_num}: Ignored template instruction/helper row.")
        next
      end
      data_rows << [row, row_num]
    end

    total_rows = data_rows.size
    if total_rows.zero?
      log_event("warn", "No question data rows found in the uploaded file.")
      finalize_import!(:completed, 0, 0, 0)
      return true
    end

    log_event("info", "Processing #{total_rows} question data rows...")

    max_position = category.questions.maximum(:position) || 0
    successful_count = 0
    failed_count = 0

    if question_import.rollback_on_error?
      # In rollback mode, execute in transaction
      begin
        ActiveRecord::Base.transaction do
          data_rows.each do |row, row_num|
            success = process_row(row, row_num, header_map, max_position + successful_count + 1)
            if success
              successful_count += 1
            else
              failed_count += 1
            end
          end

          if failed_count.positive?
            raise ActiveRecord::Rollback, "Rollback requested due to validation errors."
          end
        end

        if failed_count.positive?
          @created_question_ids.clear
          log_event("error", "Import rolled back because #{failed_count} #{'row'.pluralize(failed_count)} contained errors (All-or-nothing mode enabled).")
          finalize_import!(:failed, total_rows, 0, failed_count)
          return false
        end
      rescue => e
        @created_question_ids.clear
        log_event("error", "Transaction failed: #{e.message}")
        finalize_import!(:failed, total_rows, 0, failed_count)
        return false
      end
    else
      # Default mode: Skip invalid rows and import valid rows
      data_rows.each do |row, row_num|
        success = process_row(row, row_num, header_map, max_position + successful_count + 1)
        if success
          successful_count += 1
        else
          failed_count += 1
        end
      end
    end

    status = if question_import.dry_run?
               failed_count.positive? ? :partially_completed : :completed
             elsif failed_count.zero?
               :completed
             elsif successful_count.positive?
               :partially_completed
             else
               :failed
             end

    log_event("info", "Import finished with status '#{status}'. Succeeded: #{successful_count}, Failed: #{failed_count}, Total: #{total_rows}.")
    finalize_import!(status, total_rows, successful_count, failed_count)
    true
  end

  private

  def normalize_encoding(raw_content)
    return "" if raw_content.blank?

    content = raw_content.force_encoding("UTF-8")
    unless content.valid_encoding?
      content = raw_content.encode("UTF-8", "ISO-8859-1", invalid: :replace, undef: :replace, replace: "")
    end
    # Remove UTF-8 Byte Order Mark (BOM) if present
    content.sub(/\A\xEF\xBB\xBF/, "")
  end

  def map_headers(headers)
    map = {}
    headers.each do |header|
      normalized = header.downcase.gsub(/[^a-z0-9]/, "")
      case normalized
      when /questiontitle/, /statement/, /title/
        map[:title] ||= header
      when /displayname/, /shortname/
        map[:display_name] ||= header
      when /fromday/, /startday/, /\Afrom\z/
        map[:from_day] ||= header
      when /today/, /endday/, /\Ato\z/
        map[:to_day] ||= header
      when /description/, /instructions/
        map[:description] ||= header
      when /questiontype/, /\Atype\z/
        map[:question_type] ||= header
      when /requiredquestion/, /required/, /isrequired/
        map[:required] ||= header
      when /activequestion/, /active/, /isactive/, /status/
        map[:active] ||= header
      when /options/, /answeroptions/, /choices/
        map[:options] ||= header
      when /maxrating/, /maximumrating/, /ratingmax/
        map[:max_rating] ||= header
      end
    end
    map
  end

  def instruction_or_empty_row?(row, header_map)
    title = row[header_map[:title]].to_s.strip
    from_day = row[header_map[:from_day]].to_s.strip
    to_day = row[header_map[:to_day]].to_s.strip
    q_type = row[header_map[:question_type]].to_s.strip

    # All fields blank
    return true if row.fields.all? { |f| f.to_s.strip.blank? }

    # Guidance row matching "e.g." or helper text
    if title.downcase.start_with?("e.g.", "eg.", "example:")
      return true
    end

    if from_day.downcase.include?("accept only numbers") || to_day.downcase.include?("accept only numbers")
      return true
    end

    if title.blank? && (q_type.downcase.include?("checkboxes") || q_type.downcase.include?("short answer") || q_type.downcase.include?("etc"))
      return true
    end

    false
  end

  def process_row(row, row_num, header_map, next_position)
    raw_title = row[header_map[:title]].to_s.strip
    raw_display_name = row[header_map[:display_name]].to_s.strip.presence
    raw_from_day = row[header_map[:from_day]].to_s.strip
    raw_to_day = row[header_map[:to_day]].to_s.strip
    raw_desc = row[header_map[:description]].to_s.strip.presence
    raw_type = row[header_map[:question_type]].to_s.strip
    raw_req = row[header_map[:required]].to_s.strip
    raw_active = row[header_map[:active]].to_s.strip
    raw_opts = row[header_map[:options]].to_s.strip
    raw_max_rating = row[header_map[:max_rating]].to_s.strip

    row_errors = []

    # Title check
    if raw_title.blank?
      row_errors << "Question Title / Statement cannot be blank"
    end

    # Question Type check
    normalized_type_key = raw_type.downcase.gsub(/[-_\s]+/, " ").strip
    question_type = TYPE_MAPPINGS[normalized_type_key] || TYPE_MAPPINGS[normalized_type_key.gsub(" ", "_")]

    if question_type.nil?
      allowed_types = "Short Answer, Paragraph, Multiple Choice, Checkboxes, Dropdown, Date, Time, Rating, Number, Yes or No"
      row_errors << "Invalid Question Type '#{raw_type}'. Supported types are: #{allowed_types}"
    end

    # Day Range checks
    max_cat_days = category.duration_days.presence || 30
    from_day = 1
    if raw_from_day.present?
      if raw_from_day =~ /\A\d+\z/
        from_day = raw_from_day.to_i
        if from_day < 1
          row_errors << "From Day must be greater than or equal to 1"
        elsif from_day > max_cat_days
          row_errors << "From Day (#{from_day}) cannot exceed category maximum duration of #{max_cat_days} days"
        end
      else
        row_errors << "From Day must be a valid number (e.g. 1)"
      end
    end

    to_day = max_cat_days
    if raw_to_day.present?
      if raw_to_day =~ /\A\d+\z/
        to_day = raw_to_day.to_i
        if to_day < from_day
          row_errors << "To Day (#{to_day}) must be greater than or equal to From Day (#{from_day})"
        elsif to_day > max_cat_days
          row_errors << "To Day (#{to_day}) cannot exceed category maximum duration of #{max_cat_days} days"
        end
      else
        row_errors << "To Day must be a valid number (e.g. #{max_cat_days})"
      end
    end

    # Boolean attributes
    is_required = ["yes", "true", "1", "y"].include?(raw_req.downcase)
    is_active = raw_active.blank? || ["yes", "true", "1", "y"].include?(raw_active.downcase)

    # Max Rating check
    max_rating = 5
    if question_type == :rating && raw_max_rating.present?
      if raw_max_rating =~ /\A\d+\z/
        r_val = raw_max_rating.to_i
        max_rating = [[r_val, 1].max, 10].min
      end
    end

    # Options parsing
    parsed_options = []
    if question_type.present?
      if [:multiple_choice, :checkboxes, :dropdown].include?(question_type)
        if raw_opts.present?
          parsed_options = if raw_opts.include?("|")
                             raw_opts.split(/[\n|]/).map(&:strip).reject(&:blank?)
                           else
                             raw_opts.split(/[\n,]/).map(&:strip).reject(&:blank?)
                           end.uniq
        end

        if parsed_options.size < 2
          row_errors << "Questions of type '#{question_type.to_s.titleize}' require at least 2 options in 'Options' column (separated by |)"
        end
      elsif question_type == :yes_or_no
        if raw_opts.present?
          parsed_options = if raw_opts.include?("|")
                             raw_opts.split(/[\n|]/).map(&:strip).reject(&:blank?)
                           else
                             raw_opts.split(/[\n,]/).map(&:strip).reject(&:blank?)
                           end.uniq
        else
          parsed_options = ["Yes", "No"]
        end
      end
    end

    if row_errors.any?
      log_event("error", "Row #{row_num} [#{raw_title.presence || 'Untitled'}]: #{row_errors.join('; ')}")
      @errors_list << {
        row: row_num,
        title: raw_title.presence || "Untitled (Row #{row_num})",
        errors: row_errors,
        raw_data: row.to_h
      }
      return false
    end

    # If dry-run, we simulate successful creation
    if question_import.dry_run?
      log_event("info", "Row #{row_num} [Dry-Run]: Validated '#{raw_title}' (#{question_type.to_s.titleize}, Day #{from_day} - #{to_day})")
      return true
    end

    # Build Question Record
    question = category.questions.build(
      institute_id: category.institute_id,
      title: raw_title,
      display_name: raw_display_name,
      description: raw_desc,
      question_type: question_type,
      from_day: from_day,
      to_day: to_day,
      required: is_required,
      active: is_active,
      max_rating: (question_type == :rating ? max_rating : 5),
      position: next_position
    )

    parsed_options.each do |opt_text|
      question.options.build(text: opt_text, value: opt_text)
    end

    if question.save
      @created_question_ids << question.id
      opts_note = parsed_options.any? ? " with #{parsed_options.size} options" : ""
      log_event("success", "Row #{row_num}: Created question '#{question.title}' (#{question.question_type.titleize}, Day #{from_day}-#{to_day})#{opts_note}.")
      true
    else
      err_messages = question.errors.full_messages
      log_event("error", "Row #{row_num} save failed: #{err_messages.join('; ')}")
      @errors_list << {
        row: row_num,
        title: raw_title,
        errors: err_messages,
        raw_data: row.to_h
      }
      false
    end
  end

  def log_event(level, message)
    timestamp = Time.current.strftime("%H:%M:%S")
    entry = {
      "time" => timestamp,
      "level" => level,
      "message" => message
    }
    @logs << entry
  end

  def finalize_import!(status, total, success, failed)
    question_import.update_columns(
      status: QuestionImport.statuses[status.to_s],
      total_rows: total,
      successful_rows: success,
      failed_rows: failed,
      error_log: @errors_list,
      process_log: @logs,
      imported_question_ids: @created_question_ids,
      updated_at: Time.current
    )
  end

  def parse_file_data(raw_data, filename)
    name = filename.to_s.downcase

    if name.end_with?(".xlsx") || raw_data.start_with?("PK\x03\x04")
      parse_xlsx_data(raw_data)
    elsif name.end_with?(".xls") || raw_data.include?("urn:schemas-microsoft-com:office:spreadsheet") || raw_data.include?("<Workbook")
      parse_spreadsheet_ml_data(raw_data)
    else
      parse_csv_data(raw_data)
    end
  end

  def parse_csv_data(raw_data)
    content = normalize_encoding(raw_data)
    csv_table = CSV.parse(content, headers: true, skip_blanks: true)
    headers = csv_table.headers.compact.map(&:to_s).map(&:strip)
    rows = csv_table.map { |r| r }
    [headers, rows]
  rescue CSV::MalformedCSVError => e
    log_event("error", "CSV parsing failed: #{e.message}")
    [[], []]
  end

  def parse_spreadsheet_ml_data(raw_data)
    content = normalize_encoding(raw_data)
    doc = Nokogiri::XML(content)
    doc.remove_namespaces!

    row_nodes = doc.xpath("//Table/Row | //Row")
    return [[], []] if row_nodes.empty?

    extracted_rows = []
    row_nodes.each do |row_node|
      cells = []
      col_idx = 1
      row_node.xpath("./Cell").each do |cell_node|
        index_attr = cell_node["Index"]
        if index_attr.present?
          target_col = index_attr.to_i
          while col_idx < target_col
            cells << ""
            col_idx += 1
          end
        end
        data_node = cell_node.at_xpath("./Data")
        cells << (data_node ? data_node.text.to_s.strip : "")
        col_idx += 1
      end
      extracted_rows << cells unless cells.all?(&:blank?)
    end

    return [[], []] if extracted_rows.empty?

    headers = extracted_rows.first.map(&:to_s).map(&:strip)
    data_rows = extracted_rows[1..].map do |row_values|
      padded_values = headers.each_with_index.map { |_, i| row_values[i].to_s }
      CSV::Row.new(headers, padded_values)
    end

    [headers, data_rows]
  rescue => e
    log_event("error", "Excel XML parsing failed: #{e.message}")
    [[], []]
  end

  def parse_xlsx_data(raw_data)
    require "zip"
    temp_file = Tempfile.new(["import", ".xlsx"])
    temp_file.binmode
    temp_file.write(raw_data)
    temp_file.close

    shared_strings = []
    sheet_xml = nil

    Zip::File.open(temp_file.path) do |zip_file|
      ss_entry = zip_file.find_entry("xl/sharedStrings.xml")
      if ss_entry
        ss_doc = Nokogiri::XML(ss_entry.get_input_stream.read)
        ss_doc.remove_namespaces!
        shared_strings = ss_doc.xpath("//si").map do |si|
          si.xpath(".//t").map(&:text).join
        end
      end

      sheet_entry = zip_file.glob("xl/worksheets/sheet*.xml").first
      sheet_xml = sheet_entry.get_input_stream.read if sheet_entry
    end

    return [[], []] unless sheet_xml

    doc = Nokogiri::XML(sheet_xml)
    doc.remove_namespaces!

    extracted_rows = []
    doc.xpath("//sheetData/row").each do |row_node|
      row_cells = []
      row_node.xpath("./c").each do |c_node|
        cell_type = c_node["t"]
        v_node = c_node.at_xpath("./v")
        is_node = c_node.at_xpath("./is/t")

        val = if is_node
          is_node.text
        elsif v_node
          v_text = v_node.text
          cell_type == "s" ? (shared_strings[v_text.to_i] || "") : v_text
        else
          ""
        end
        row_cells << val.to_s.strip
      end
      extracted_rows << row_cells unless row_cells.all?(&:blank?)
    end

    return [[], []] if extracted_rows.empty?

    headers = extracted_rows.first.map(&:to_s).map(&:strip)
    data_rows = extracted_rows[1..].map do |row_values|
      padded_values = headers.each_with_index.map { |_, i| row_values[i].to_s }
      CSV::Row.new(headers, padded_values)
    end

    [headers, data_rows]
  rescue LoadError, StandardError => e
    log_event("error", "XLSX parsing failed: #{e.message}")
    [[], []]
  ensure
    temp_file&.unlink if temp_file
  end
end
