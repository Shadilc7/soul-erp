# =============================================================================
# Bulk Participant Import Script
# Usage (Rails console):
#   load 'lib/tasks/import_participants.rb'
#   BulkParticipantImport.run('path/to/participants.csv', institute_id: 1)
#
# CSV columns (tab-separated or comma-separated):
#   Full Name, Email Address, Phone Number, Date of Birth (DD/MM/YYYY),
#   Address, PIN Code, District, State, Participant Type, Institution (ignored),
#   Section(Batch)
#
# Notes:
#   - Generates a unique 10-char password for every participant.
#   - Sets user active: true (approved) automatically.
#   - Prints a summary table and saves a credentials CSV at the end.
# =============================================================================

require "csv"
require "securerandom"

module BulkParticipantImport
  # ---------------------------------------------------------------------------
  # Detect separator (tab or comma)
  # ---------------------------------------------------------------------------
  def self.detect_separator(file_path)
    first_line = File.open(file_path, "r:bom|utf-8", &:readline)
    first_line.count("\t") >= first_line.count(",") ? "\t" : ","
  end

  # ---------------------------------------------------------------------------
  # Generate a simple, memorable password
  # Pattern: FirstName@BirthYear  →  e.g. "Juwan@2009"
  # Falls back to FirstName@NNNN (random 4 digits) when DOB is missing.
  # ---------------------------------------------------------------------------
  def self.generate_password(first_name, dob = nil)
    base = first_name.gsub(/[^a-zA-Z]/, "").capitalize.presence || "User"
    year = dob ? dob.year.to_s : rand(1000..9999).to_s
    "#{base}@#{year}"
  end

  # ---------------------------------------------------------------------------
  # Main entry point
  # ---------------------------------------------------------------------------
  def self.run(csv_path, institute_id:, dry_run: false)
    raise "File not found: #{csv_path}" unless File.exist?(csv_path)

    institute = Institute.find(institute_id)
    sep       = detect_separator(csv_path)

    results    = { created: [], skipped: [], failed: [] }
    credentials = []   # [{name:, email:, password:}, ...]

    rows = CSV.read(csv_path, headers: true, col_sep: sep,
                              header_converters: :symbol,
                              encoding: "bom|utf-8")

    puts "\n#{"=" * 70}"
    puts "Institute : #{institute.name}"
    puts "Total rows: #{rows.size}  |  Dry run: #{dry_run}"
    puts "=" * 70

    rows.each_with_index do |row, idx|
      line_no = idx + 2   # 1-based + header

      # ---- Parse fields ----------------------------------------------------
      full_name      = row[:full_name]&.strip.to_s
      email          = row[:email_address]&.strip&.downcase.to_s
      phone          = row[:phone_number]&.to_s&.gsub(/\D/, "").to_s
      dob_raw        = row[:date_of_birth]&.strip.to_s
      address        = row[:address]&.strip.to_s
      pin_code       = row[:pin_code]&.strip.to_s
      district       = row[:district]&.strip.to_s
      state          = row[:state]&.strip.to_s
      p_type_raw     = row[:participant_type]&.strip&.downcase.to_s
      section_name   = row[:sectionbatch]&.strip.to_s   # CSV header: Section(Batch)

      # ---- Basic validation ------------------------------------------------
      if full_name.blank? || email.blank?
        results[:skipped] << { line: line_no, reason: "Missing name or email", row: row.to_h }
        next
      end

      # ---- Resolve participant_type ----------------------------------------
      participant_type = case p_type_raw
      when "student"  then "student"
      when "guardian" then "guardian"
      when "employee" then "employee"
      else "student"
      end

      # ---- Parse date of birth  -------------------------------------------
      dob = begin
              Date.strptime(dob_raw, "%d/%m/%Y")
            rescue ArgumentError, TypeError
              begin
                Date.parse(dob_raw)
              rescue ArgumentError, TypeError
                nil
              end
            end

      # ---- Resolve section -------------------------------------------------
      section = institute.sections.find_by("LOWER(name) = ?", section_name.downcase)
      unless section
        results[:failed] << { line: line_no, email: email, reason: "Section '#{section_name}' not found" }
        next
      end

      # ---- Split full name into first / last --------------------------------
      name_parts = full_name.split(" ", 2)
      first_name = name_parts[0].to_s.strip
      last_name  = name_parts[1].to_s.strip

      # ---- Skip duplicates --------------------------------------------------
      if User.exists?(email: email)
        results[:skipped] << { line: line_no, email: email, reason: "Email already exists" }
        next
      end

      # ---- Build objects ---------------------------------------------------
      password = generate_password(first_name, dob)

      if dry_run
        puts "[DRY RUN] Line #{line_no}: #{full_name} <#{email}> → section=#{section.name} pwd=#{password}"
        credentials << { name: full_name, email: email, password: password }
        results[:created] << { line: line_no, email: email }
        next
      end

      ActiveRecord::Base.transaction do
        user             = User.new
        user.first_name  = first_name
        user.last_name   = last_name
        user.email       = email
        user.phone       = phone.presence
        user.password    = password
        user.password_confirmation = password
        user.role        = :participant
        user.institute   = institute
        user.section     = section
        user.active      = true   # approved immediately

        participant             = user.build_participant
        participant.institute   = institute
        participant.section_id  = section.id
        participant.participant_type = participant_type
        participant.phone_number = phone.presence
        participant.date_of_birth = dob
        participant.enrollment_date = Date.current
        participant.address   = address.presence
        participant.pin_code  = pin_code.presence
        participant.district  = district.presence
        participant.state     = state.presence

        if user.save
          results[:created] << { line: line_no, email: email, name: full_name }
          credentials << { name: full_name, email: email, password: password }
          print "."
        else
          errors = user.errors.full_messages.join("; ")
          results[:failed] << { line: line_no, email: email, reason: errors }
          raise ActiveRecord::Rollback
        end
      end
    rescue => e
      results[:failed] << { line: line_no, email: email, reason: e.message }
    end

    # ---- Summary -----------------------------------------------------------
    puts "\n\n#{"=" * 70}"
    puts "RESULTS"
    puts "  Created : #{results[:created].size}"
    puts "  Skipped : #{results[:skipped].size}"
    puts "  Failed  : #{results[:failed].size}"

    if results[:skipped].any?
      puts "\nSkipped:"
      results[:skipped].each { |s| puts "  Line #{s[:line]} – #{s[:email] || '?'} – #{s[:reason]}" }
    end

    if results[:failed].any?
      puts "\nFailed:"
      results[:failed].each { |f| puts "  Line #{f[:line]} – #{f[:email] || '?'} – #{f[:reason]}" }
    end

    # ---- Save credentials CSV ---------------------------------------------
    unless dry_run || credentials.empty?
      out_path = Rails.root.join("tmp", "participant_credentials_#{Time.current.strftime('%Y%m%d_%H%M%S')}.csv")
      CSV.open(out_path, "w") do |csv|
        csv << [ "Full Name", "Email", "Password" ]
        credentials.each { |c| csv << [ c[:name], c[:email], c[:password] ] }
      end
      puts "\nCredentials saved to: #{out_path}"
    end

    puts "=" * 70
    results
  end
end
