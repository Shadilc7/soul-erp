module InstituteAdmin
  class ReportsController < InstituteAdmin::BaseController
    def index
      # Just show the main reports navigation page
    end

    def assignment_reports_menu
      # Show menu for assignment reports types
    end

    def assignment_reports
      @date_range = params[:date_range]
      @start_date = params[:start_date].present? ? Date.parse(params[:start_date]) : Date.current
      @end_date = params[:end_date].present? ? Date.parse(params[:end_date]) : Date.current
      @section_id = params[:section_id]
      @assignment_id = params[:assignment_id]

      # Always fetch reports for CSV/PDF format, or when filter is applied in HTML format
      if params[:format].in?([ "csv", "pdf" ]) || (params[:commit].present? && params[:submission_status].present?)
        fetch_assignment_reports
      end

      respond_to do |format|
        format.html
        format.csv {
          if @submitted_logs.nil? && @not_submitted_participants.nil?
            # Initialize empty collections to prevent nil errors
            @submitted_logs = []
            @not_submitted_participants = []
          end
          send_data generate_assignment_csv, filename: "assignment_report_#{Date.current}.csv"
        }
        format.pdf {
          if @submitted_logs.nil? && @not_submitted_participants.nil?
            # Initialize empty collections to prevent nil errors
            @submitted_logs = []
            @not_submitted_participants = []
          end

          # Render PDF using Prawn or WickedPDF
          render_assignment_report_pdf
        }
      end
    end

    def feedback_reports
      # Just show the feedback reports menu page
    end

    def section_feedback_reports
      @date_range = params[:date_range]
      @start_date = params[:start_date].present? ? Date.parse(params[:start_date]) : Date.current
      @end_date = params[:end_date].present? ? Date.parse(params[:end_date]) : Date.current
      @section_id = params[:section_id]
      @training_program_id = params[:training_program_id]

      # Always fetch reports for CSV/PDF format, or when filter is applied in HTML format
      if params[:format].in?([ "csv", "pdf" ]) || (params[:commit].present? && params[:submission_status].present?)
        fetch_section_feedback_reports
      end

      respond_to do |format|
        format.html
        format.csv {
          if @submitted_feedbacks.nil? && @not_submitted_participants.nil?
            # Initialize empty collections to prevent nil errors
            @submitted_feedbacks = []
            @not_submitted_participants = []
          end
          send_data generate_section_feedback_csv, filename: "section_feedback_report_#{Date.current}.csv"
        }
        format.pdf {
          if @submitted_feedbacks.nil? && @not_submitted_participants.nil?
            # Initialize empty collections to prevent nil errors
            @submitted_feedbacks = []
            @not_submitted_participants = []
          end

          # Render PDF using Prawn or WickedPDF
          render_section_feedback_report_pdf
        }
      end
    end

    def individual_feedback_reports
      @date_range = params[:date_range]
      @start_date = params[:start_date].present? ? Date.parse(params[:start_date]) : Date.current
      @end_date = params[:end_date].present? ? Date.parse(params[:end_date]) : Date.current
      @section_id = params[:section_id]
      @participant_id = params[:participant_id]
      @training_program_id = params[:training_program_id]

      # Load participants for the selected section
      @participants = if @section_id.present?
                       current_institute.participants.includes(:user).where(section_id: @section_id)
      else
                       []
      end

      # Always fetch reports for CSV/PDF format, or when filter is applied in HTML format
      if params[:format].in?([ "csv", "pdf" ]) || (params[:commit].present? && params[:submission_status].present?)
        fetch_individual_feedback_reports
      end

      respond_to do |format|
        format.html
        format.csv {
          if @submitted_feedbacks.nil? && @not_submitted_training_programs.nil?
            # Initialize empty collections to prevent nil errors
            @submitted_feedbacks = []
            @not_submitted_training_programs = []
          end
          send_data generate_individual_feedback_csv, filename: "individual_feedback_report_#{Date.current}.csv"
        }
        format.pdf {
          if @submitted_feedbacks.nil? && @not_submitted_training_programs.nil?
            # Initialize empty collections to prevent nil errors
            @submitted_feedbacks = []
            @not_submitted_training_programs = []
          end

          # Render PDF using Prawn or WickedPDF
          render_individual_feedback_report_pdf
        }
      end
    end

    def certificates
      # Handle certificate options page
    end

    def generate_certificate
      @sections = current_institute.sections.active
      @certificate_configurations = current_institute.certificate_configurations.active

      # Load data based on parameters
      @section_id = params[:section_id]
      @participant_id = params[:participant_id]
      @assignment_id = params[:assignment_id]

      # Load participants if section is selected
      @participants = if @section_id.present?
                       current_institute.participants.includes(:user).where(section_id: @section_id)
      else
                       []
      end

      # Load assignments if participant is selected
      @assignments = if @participant_id.present?
                      participant = current_institute.participants.find_by(id: @participant_id)

                      if participant
                        # Get all assignments for this participant (both individual and section assignments)
                        individual_assignments = Assignment.joins(:assignment_participants)
                                                        .where(assignment_participants: { participant_id: @participant_id })

                        section_assignments = Assignment.joins(:assignment_sections)
                                                     .where(assignment_sections: { section_id: participant.section_id })

                        Assignment.where(id: individual_assignments.pluck(:id) + section_assignments.pluck(:id))
                                .distinct.order(created_at: :desc)
                      else
                        []
                      end
      else
                      []
      end
    end

    def create_certificate
      @section_id = params[:section_id]
      @participant_id = params[:participant_id]
      @assignment_id = params[:assignment_id]
      @certificate_configuration_id = params[:certificate_configuration_id]

      # Validate all required parameters
      unless @section_id.present? && @participant_id.present? && @assignment_id.present? && @certificate_configuration_id.present?
        redirect_to generate_certificate_institute_admin_reports_path, alert: "All fields are required"
        return
      end

      # Find records
      @participant = current_institute.participants.find_by(id: @participant_id)
      @assignment = current_institute.assignments.find_by(id: @assignment_id)
      @certificate_configuration = current_institute.certificate_configurations.find_by(id: @certificate_configuration_id)

      # Validate records exist
      errors = []
      errors << "Participant not found" unless @participant
      errors << "Assignment not found" unless @assignment
      errors << "Certificate configuration not found" unless @certificate_configuration

      if errors.any?
        redirect_to generate_certificate_institute_admin_reports_path, alert: "Invalid selection: #{errors.join(', ')}"
        return
      end

      # Check if this certificate already exists
      if IndividualCertificate.exists?(
          participant_id: @participant_id,
          assignment_id: @assignment_id,
          certificate_configuration_id: @certificate_configuration_id
        )
        redirect_to view_certificates_institute_admin_reports_path, alert: "A certificate already exists for this participant and assignment"
        return
      end

      # Create certificate record
      @certificate = IndividualCertificate.new(
        participant: @participant,
        assignment: @assignment,
        certificate_configuration: @certificate_configuration,
        institute: current_institute
      )

      if @certificate.save
        redirect_to view_certificates_institute_admin_reports_path,
                    notice: "Certificate successfully generated. <a href='#{show_certificate_on_demand_institute_admin_report_path(@certificate)}' target='_blank'>View Certificate</a>".html_safe
      else
        redirect_to generate_certificate_institute_admin_reports_path(
          section_id: @section_id,
          participant_id: @participant_id,
          assignment_id: @assignment_id,
          certificate_configuration_id: @certificate_configuration_id
        ), alert: "Failed to generate certificate: #{@certificate.errors.full_messages.join(', ')}"
      end
    end

    def generate_section_certificate
      @sections = current_institute.sections.active
      @certificate_configurations = current_institute.certificate_configurations.active
      @assignments = current_institute.assignments.order(created_at: :desc)

      # optionally preselect section from params
      @section_id = params[:section_id]
    end

    def create_section_certificate
      section_id = params[:section_id]
      assignment_id = params[:assignment_id]
      certificate_configuration_id = params[:certificate_configuration_id]

      unless section_id.present? && assignment_id.present? && certificate_configuration_id.present?
        redirect_to generate_section_certificate_institute_admin_reports_path, alert: "All fields are required"
        return
      end

      section = current_institute.sections.find_by(id: section_id)
      assignment = current_institute.assignments.find_by(id: assignment_id)
      certificate_configuration = current_institute.certificate_configurations.find_by(id: certificate_configuration_id)

      errors = []
      errors << "Section not found" unless section
      errors << "Assignment not found" unless assignment
      errors << "Certificate configuration not found" unless certificate_configuration

      if errors.any?
        redirect_to generate_section_certificate_institute_admin_reports_path, alert: "Invalid selection: #{errors.join(', ')}"
        return
      end

      participants = current_institute.participants.where(section_id: section.id)

      created = 0
      skipped = 0
      failed = 0
      failures = []

      IndividualCertificate.transaction do
        participants.find_each do |participant|
          existing = IndividualCertificate.find_by(participant_id: participant.id, assignment_id: assignment.id, certificate_configuration_id: certificate_configuration.id)
          if existing
            skipped += 1
            next
          end

          cert = IndividualCertificate.new(
            participant: participant,
            assignment: assignment,
            certificate_configuration: certificate_configuration,
            institute: current_institute
          )

          if cert.save
            # attempt to generate PDF now; capture failures but do not rollback entire transaction for generation errors
            begin
              success = generate_individual_certificate(cert)
              if success
                created += 1
              else
                failed += 1
                failures << "#{participant.full_name}: generation failed"
              end
            rescue => e
              failed += 1
              failures << "#{participant.full_name}: #{e.message}"
            end
          else
            failed += 1
            failures << "#{participant.full_name}: #{cert.errors.full_messages.join(', ')}"
          end
        end
      end

      notice_parts = []
      notice_parts << "Created: #{created}" if created > 0
      notice_parts << "Skipped (already exists): #{skipped}" if skipped > 0
      notice_parts << "Failed: #{failed}" if failed > 0

      if failures.any?
        redirect_to view_certificates_institute_admin_reports_path, alert: "Section generation completed - #{notice_parts.join(', ')}. Errors: #{failures.join('; ')}"
      else
        redirect_to view_certificates_institute_admin_reports_path, notice: "Section generation completed - #{notice_parts.join(', ')}"
      end
    end

    def view_certificates
      # Read optional filters
      @section_id = params[:section_id]
      @certificate_configuration_id = params[:certificate_configuration_id]

      # Load available configurations for the filter dropdown
      @certificate_configurations = current_institute.certificate_configurations.active

      # Build base query
      base = IndividualCertificate.includes(:participant, :assignment, :certificate_configuration)
                   .where(institute_id: current_institute.id)

      # Apply section filter (via participant's section)
      if @section_id.present?
        base = base.joins(participant: :section).where(participants: { section_id: @section_id })
      end

      # Apply certificate configuration filter
      if @certificate_configuration_id.present?
        base = base.where(certificate_configuration_id: @certificate_configuration_id)
      end

      # Pagination and ordering
      @certificates = base.order(generated_at: :desc).page(params[:page]).per(10)

      # Get section-wise certificate counts for the bar graph
      @section_certificate_counts = IndividualCertificate.joins(participant: :section)
                                            .where(institute_id: current_institute.id)
                                            .group("sections.name")
                                            .order("sections.name")
                                            .count
    end

    def show_certificate
      @certificate = current_institute.individual_certificates.find(params[:id])

      # Generate PDF content on-demand
      pdf_content = generate_individual_certificate(@certificate)

      if pdf_content
        send_data pdf_content,
                  filename: "certificate_#{@certificate.id}.pdf",
                  type: "application/pdf",
                  disposition: "inline"
      else
        redirect_to view_certificates_institute_admin_reports_path,
                    alert: "Failed to generate certificate: #{@certificate.errors.full_messages.join(', ')}"
      end
    end

    def delete_certificate
      @certificate = current_institute.individual_certificates.find(params[:id])

      # Delete the physical file if it exists
      File.delete(@certificate.file_path) if @certificate.filename.present? && File.exist?(@certificate.file_path)

      # Delete the record
      @certificate.destroy

      redirect_to view_certificates_institute_admin_reports_path, notice: "Certificate successfully deleted"
    end

    def regenerate_certificate
      @certificate = current_institute.individual_certificates.find(params[:id])

      # Delete the existing file if it exists
      if @certificate.filename.present? && File.exist?(@certificate.file_path)
        File.delete(@certificate.file_path)
      end

      # Regenerate the certificate PDF
      success = generate_individual_certificate(@certificate)

      if success && @certificate.save
        redirect_to view_certificates_institute_admin_reports_path, notice: "Certificate successfully regenerated. <a href='#{show_certificate_institute_admin_reports_path(@certificate)}' target='_blank'>View Certificate</a>".html_safe
      else
        error_messages = @certificate.errors.full_messages
        error_messages << "Failed to regenerate certificate PDF" unless success
        redirect_to view_certificates_institute_admin_reports_path, alert: "Failed to regenerate certificate: #{error_messages.join(', ')}"
      end
    end

    def show_certificate_on_demand
      @certificate = current_institute.individual_certificates.find(params[:id])

      # Generate PDF content on-demand
      pdf_content = generate_individual_certificate(@certificate)

      if pdf_content
        send_data pdf_content,
                  filename: "certificate_#{@certificate.id}.pdf",
                  type: "application/pdf",
                  disposition: "inline"
      else
        redirect_to view_certificates_institute_admin_reports_path,
                    alert: "Failed to generate certificate: #{@certificate.errors.full_messages.join(', ')}"
      end
    end

    def download_certificate_on_demand
      @certificate = current_institute.individual_certificates.find(params[:id])

      # Generate PDF content on-demand
      pdf_content = generate_individual_certificate(@certificate)

      if pdf_content
        send_data pdf_content,
                  filename: "certificate_#{@certificate.id}.pdf",
                  type: "application/pdf",
                  disposition: "attachment"
      else
        redirect_to view_certificates_institute_admin_reports_path,
                    alert: "Failed to generate certificate: #{@certificate.errors.full_messages.join(', ')}"
      end
    end

    def individual_assignment_reports
      @date_range = params[:date_range]
      @start_date = params[:start_date].present? ? Date.parse(params[:start_date]) : Date.current
      @end_date = params[:end_date].present? ? Date.parse(params[:end_date]) : Date.current
      @section_id = params[:section_id]
      @participant_id = params[:participant_id]
      @assignment_id = params[:assignment_id]

      # Load participants for the selected section
      @participants = if @section_id.present?
                       current_institute.participants.includes(:user).where(section_id: @section_id)
      else
                       []
      end

      # Always fetch reports for CSV/PDF format, or when filter is applied in HTML format
      if params[:format].in?([ "csv", "pdf" ]) || (params[:commit].present? && params[:submission_status].present?)
        fetch_individual_assignment_reports
      end

      respond_to do |format|
        format.html
        format.csv {
          if @submitted_logs.nil? && @not_submitted_assignments.nil?
            # Initialize empty collections to prevent nil errors
            @submitted_logs = []
            @not_submitted_assignments = []
          end
          send_data generate_individual_assignment_csv, filename: "individual_assignment_report_#{Date.current}.csv"
        }
        format.pdf {
          if @submitted_logs.nil? && @not_submitted_assignments.nil?
            # Initialize empty collections to prevent nil errors
            @submitted_logs = []
            @not_submitted_assignments = []
          end

          # Render PDF using Prawn or WickedPDF
          render_individual_assignment_report_pdf
        }
      end
    end

    def certificate_stats
      # Get certificates for current institute only
      base_query = IndividualCertificate.joins(:certificate_configuration)
                             .where(certificate_configurations: { institute_id: current_institute.id })

      # Get total count of certificates
      @total_certificates = base_query.count

      # Get certificates created in the last 7 days
      @recent_certificates = base_query.where("individual_certificates.created_at >= ?", 7.days.ago).count

      # Get certificate types (distinct configurations)
      @certificate_types = current_institute.certificate_configurations.count

      # Get certificate count by configuration
      @certificates_by_config = base_query.group("certificate_configurations.name")
                                        .order("count_all DESC")
                                        .count

      # Get certificates by month for the current year
      @certificates_by_month = base_query.where("individual_certificates.created_at >= ?", Time.zone.now.beginning_of_year)
                                       .group(Arel.sql("DATE_TRUNC('month', individual_certificates.created_at)"))
                                       .order(Arel.sql("DATE_TRUNC('month', individual_certificates.created_at)"))
                                       .count
                                       .transform_keys { |k| k.strftime("%B") }

      # Get top 10 participants with most certificates
      @top_participants = base_query.joins(participant: :user)
                                   .group(Arel.sql("users.first_name || ' ' || users.last_name"))
                                   .order("count_all DESC")
                                   .limit(10)
                                   .count

      # Get certificates by section
      @certificates_by_section = base_query.joins(participant: :section)
                                         .group("sections.name")
                                         .order("count_all DESC")
                                         .count

      # Monthly growth rate
      current_month_count = base_query.where("individual_certificates.created_at >= ?", Time.zone.now.beginning_of_month).count
      previous_month_count = base_query.where("individual_certificates.created_at >= ? AND individual_certificates.created_at <= ?",
                                             1.month.ago.beginning_of_month,
                                             1.month.ago.end_of_month).count
      @monthly_growth = previous_month_count.zero? ? 100 : ((current_month_count - previous_month_count).to_f / previous_month_count * 100).round(2)

      render :certificate_stats
    end

    def certificate_configurations
      @certificate_configs = CertificateConfiguration.order(created_at: :desc)
                                                  .page(params[:page]).per(10)
    end

    def toggle_publish_certificate
      @certificate = current_institute.individual_certificates.find(params[:id])
      @certificate.update(published: !@certificate.published)

      redirect_to view_certificates_institute_admin_reports_path,
                  notice: "Certificate #{@certificate.published? ? 'published' : 'unpublished'} successfully"
    end

    def publish_multiple_certificates
      certificate_ids = params[:certificate_ids]
      certificates = current_institute.individual_certificates.where(id: certificate_ids)

      begin
        IndividualCertificate.transaction do
          certificates.update_all(published: true)
        end

        render json: { success: true, message: "Successfully published #{certificates.count} certificates" }
      rescue => e
        render json: { success: false, message: e.message }, status: :unprocessable_entity
      end
    end

    def delete_multiple_certificates
      certificate_ids = params[:certificate_ids]
      certificates = current_institute.individual_certificates.where(id: certificate_ids)

      begin
        IndividualCertificate.transaction do
          certificates.find_each do |cert|
            # attempt to delete the file if present
            File.delete(cert.file_path) if cert.filename.present? && File.exist?(cert.file_path)
            cert.destroy
          end
        end

        render json: { success: true, message: "Successfully deleted #{certificates.count} certificates" }
      rescue => e
        render json: { success: false, message: e.message }, status: :unprocessable_entity
      end
    end

    def unpublish_multiple_certificates
      certificate_ids = params[:certificate_ids]
      certificates = current_institute.individual_certificates.where(id: certificate_ids)

      begin
        IndividualCertificate.transaction do
          certificates.update_all(published: false)
        end

        render json: { success: true, message: "Successfully unpublished #{certificates.count} certificates" }
      rescue => e
        render json: { success: false, message: e.message }, status: :unprocessable_entity
      end
    end

    def download_multiple_certificates
      certificate_ids = params[:certificate_ids] || []
      certificates = current_institute.individual_certificates.where(id: certificate_ids)

      if certificates.empty?
        render json: { success: false, message: "No certificates found" }, status: :not_found
        return
      end

      require "zip"
      temp_file = Tempfile.new([ "certificates-", ".zip" ])
      begin
        Zip::OutputStream.open(temp_file.path) do |zos|
          certificates.find_each do |cert|
            # generate or fetch PDF content
            pdf_content = generate_individual_certificate(cert)
            next unless pdf_content
            filename = "certificate-#{cert.id}.pdf"
            zos.put_next_entry(filename)
            zos.write(pdf_content)
          end
        end

        send_data File.read(temp_file.path), filename: "certificates_#{Time.current.strftime('%Y%m%d%H%M%S')}.zip", type: "application/zip"
      ensure
        temp_file.close
        temp_file.unlink
      end
    end

    def regenerate_multiple_certificates
      certificate_ids = params[:certificate_ids] || []
      certificates = current_institute.individual_certificates.where(id: certificate_ids)

      updated = 0
      certificates.find_each do |cert|
        # remove old file if exists
        File.delete(cert.file_path) if cert.filename.present? && File.exist?(cert.file_path)
        success = generate_individual_certificate(cert)
        updated += 1 if success
      end

      render json: { success: true, message: "Regenerated #{updated} certificates" }
    end

    private

    def fetch_assignment_reports
      base_query = AssignmentResponseLog.includes(:participant, :assignment, participant: :section)
                                      .where(institute: current_institute)

      # Apply date filters
      base_query = case @date_range
      when "today"
                    base_query.where(response_date: Date.current)
      when "yesterday"
                    base_query.where(response_date: Date.yesterday)
      when "last_7_days"
                    base_query.where(response_date: 7.days.ago.beginning_of_day..Time.current)
      when "this_month"
                    base_query.where(response_date: Time.current.beginning_of_month..Time.current)
      when "custom"
                    base_query.where(response_date: @start_date.beginning_of_day..@end_date.end_of_day)
      else
                    base_query.where(response_date: Date.current)
      end

      # Apply section filter if selected
      if @section_id.present? && @section_id != "all"
        base_query = base_query.joins(participant: :section)
                              .where(sections: { id: @section_id })
      end

      # Apply assignment filter if selected
      if @assignment_id.present? && @assignment_id != "all"
        base_query = base_query.where(assignment_id: @assignment_id)
      end

      @submitted_logs = base_query.order(response_date: :desc)

      # Preload assignment responses for performance
      @assignment_responses = AssignmentResponse.where(id: @submitted_logs.map(&:assignment_response_ids).flatten).index_by(&:id)

      # Get all participants who should have submitted
      all_participants = if @section_id.present? && @section_id != "all"
                         current_institute.participants.includes(:section).where(section_id: @section_id)
      else
                         current_institute.participants.includes(:section)
      end

      # Get participants who haven't submitted
      submitted_participant_ids = @submitted_logs.pluck(:participant_id).uniq
      @not_submitted_participants = all_participants.where.not(id: submitted_participant_ids)

      # For assignment filter in non-submitted participants
      if @assignment_id.present? && @assignment_id != "all"
        assignment = current_institute.assignments.find(@assignment_id)
        @assignment_title = assignment.title
      end

      # Clear the data that's not needed based on submission status
      if params[:submission_status] == "submitted"
        @not_submitted_participants = []
      else
        @submitted_logs = []
      end
    end

    def fetch_section_feedback_reports
      base_query = TrainingProgramFeedback.includes(:participant, :training_program, participant: :section)
                                        .where(training_programs: { institute_id: current_institute.id })

      # Apply date filters
      base_query = case @date_range
      when "today"
                    base_query.where(created_at: Date.current.all_day)
      when "yesterday"
                    base_query.where(created_at: Date.yesterday.all_day)
      when "last_7_days"
                    base_query.where(created_at: 7.days.ago.beginning_of_day..Time.current)
      when "this_month"
                    base_query.where(created_at: Time.current.beginning_of_month..Time.current)
      when "custom"
                    base_query.where(created_at: @start_date.beginning_of_day..@end_date.end_of_day)
      else
                    base_query.where(created_at: Date.current.all_day)
      end

      # Apply section filter if selected
      if @section_id.present? && @section_id != "all"
        base_query = base_query.joins(participant: :section)
                              .where(sections: { id: @section_id })
      end

      @submitted_feedbacks = base_query.order(created_at: :desc)

      # Get all participants who should have submitted feedback
      all_participants = if @section_id.present? && @section_id != "all"
                         current_institute.participants.includes(:section).where(section_id: @section_id)
      else
                         current_institute.participants.includes(:section)
      end

      # Get participants who haven't submitted feedback
      submitted_participant_ids = @submitted_feedbacks.pluck(:participant_id).uniq
      @not_submitted_participants = all_participants.where.not(id: submitted_participant_ids)

      # Clear the data that's not needed based on submission status
      if params[:submission_status] == "submitted"
        @not_submitted_participants = []
      else
        @submitted_feedbacks = []
      end
    end

    def fetch_individual_assignment_reports
      # Only proceed if a participant is selected
      return if @participant_id.blank?

      participant = current_institute.participants.find(@participant_id)

      if params[:submission_status] == "submitted"
        # Get submitted assignments for the participant
        base_query = AssignmentResponseLog.includes(:participant, :assignment)
                                        .where(institute: current_institute)
                                        .where(participant_id: @participant_id)

        # Apply date filters
        base_query = case @date_range
        when "today"
                      base_query.where(response_date: Date.current)
        when "yesterday"
                      base_query.where(response_date: Date.yesterday)
        when "last_7_days"
                      base_query.where(response_date: 7.days.ago.beginning_of_day..Time.current)
        when "this_month"
                      base_query.where(response_date: Time.current.beginning_of_month..Time.current)
        when "custom"
                      base_query.where(response_date: @start_date.beginning_of_day..@end_date.end_of_day)
        else
                      base_query.where(response_date: Date.current)
        end

        # Apply assignment filter if selected
        if @assignment_id.present? && @assignment_id != "all"
          base_query = base_query.where(assignment_id: @assignment_id)
        end

        @submitted_logs = base_query.order(response_date: :desc)
        @not_submitted_assignments = []
      else
        # Get all assignments the participant should have completed
        available_assignments = Assignment.where(institute: current_institute)
                                       .active
                                       .where("end_date >= ?", @start_date)
                                       .where("start_date <= ?", @end_date)

        # Filter by specific assignment if selected
        if @assignment_id.present? && @assignment_id != "all"
          available_assignments = available_assignments.where(id: @assignment_id)
        end

        # Find assignments applicable to this participant
        participant_assignments = available_assignments.select do |assignment|
          if assignment.assignment_type == "individual"
            assignment.participants.include?(participant)
          else
            assignment.sections.include?(participant.section)
          end
        end

        # Find which assignments haven't been submitted
        submitted_assignment_ids = AssignmentResponseLog.where(participant_id: @participant_id)
                                                     .where(response_date: @start_date.beginning_of_day..@end_date.end_of_day)
                                                     .pluck(:assignment_id)
                                                     .uniq

        @not_submitted_assignments = participant_assignments.reject { |a| submitted_assignment_ids.include?(a.id) }
        @submitted_logs = []
      end
    end

    def fetch_individual_feedback_reports
      # Only proceed if a participant is selected
      return if @participant_id.blank?

      participant = current_institute.participants.find(@participant_id)

      if params[:submission_status] == "submitted"
        # Get submitted feedbacks for the participant
        base_query = TrainingProgramFeedback.includes(:training_program)
                                        .where(participant_id: @participant_id)

        # Apply date filters
        base_query = case @date_range
        when "today"
                      base_query.where(created_at: Date.current.all_day)
        when "yesterday"
                      base_query.where(created_at: Date.yesterday.all_day)
        when "last_7_days"
                      base_query.where(created_at: 7.days.ago.beginning_of_day..Time.current)
        when "this_month"
                      base_query.where(created_at: Time.current.beginning_of_month..Time.current)
        when "custom"
                      base_query.where(created_at: @start_date.beginning_of_day..@end_date.end_of_day)
        else
                      base_query.where(created_at: Date.current.all_day)
        end

        # Apply training program filter if selected
        if @training_program_id.present? && @training_program_id != "all"
          base_query = base_query.where(training_program_id: @training_program_id)
        end

        @submitted_feedbacks = base_query.order(created_at: :desc)
        @not_submitted_training_programs = []
      else
        # Get all training programs the participant should have given feedback for
        available_programs = participant.all_training_programs
                                    .where(institute: current_institute)
                                    .where("end_date >= ?", @start_date)
                                    .where("start_date <= ?", @end_date)

        # Filter by specific training program if selected
        if @training_program_id.present? && @training_program_id != "all"
          available_programs = available_programs.where(id: @training_program_id)
        end

        # Find which training programs haven't received feedback
        submitted_program_ids = TrainingProgramFeedback.where(participant_id: @participant_id)
                                                   .where(created_at: @start_date.beginning_of_day..@end_date.end_of_day)
                                                   .pluck(:training_program_id)
                                                   .uniq

        @not_submitted_training_programs = available_programs.reject { |tp| submitted_program_ids.include?(tp.id) }
        @submitted_feedbacks = []
      end
    end

    def generate_assignment_csv
      require "csv"

      CSV.generate(headers: true) do |csv|
        if params[:submission_status] == "submitted"
          # Generate submitted assignments CSV
          header_row = [ "Date", "Participant", "Section", "Responses" ]

          # Add assignment column to the header if no specific assignment is selected
          header_row.insert(3, "Assignment") if @assignment_id.blank? || @assignment_id == "all"

          csv << header_row

          @submitted_logs.each do |log|
            row = [
              log.response_date.strftime("%B %d, %Y"),
              log.participant.full_name,
              log.participant.section.name
            ]

            # Add assignment title if no specific assignment is selected
            row << log.assignment.title if @assignment_id.blank? || @assignment_id == "all"

            row << log.assignment_response_ids.size

            csv << row
          end
        else
          # Generate not submitted assignments CSV
          header_row = [ "Participant", "Section", "Email" ]

          # Add assignment column to the header if specific assignment is selected
          header_row << "Assignment" if @assignment_id.present? && @assignment_id != "all"

          csv << header_row

          @not_submitted_participants.each do |participant|
            row = [
              participant.full_name,
              participant.section.name,
              participant.email
            ]

            # Add assignment title if specific assignment is selected
            row << @assignment_title if @assignment_id.present? && @assignment_id != "all"

            csv << row
          end
        end
      end
    end

    def generate_section_feedback_csv
      require "csv"

      CSV.generate(headers: true) do |csv|
        if params[:submission_status] == "submitted"
          # Generate submitted feedbacks CSV
          csv << [ "Date", "Participant", "Section", "Training Program", "Rating", "Content" ]
          @submitted_feedbacks.each do |feedback|
            csv << [
              feedback.created_at.strftime("%B %d, %Y"),
              feedback.participant.full_name,
              feedback.participant.section.name,
              feedback.training_program.title,
              feedback.rating,
              feedback.content
            ]
          end
        else
          # Generate not submitted feedbacks CSV
          csv << [ "Participant", "Section", "Email" ]
          @not_submitted_participants.each do |participant|
            csv << [
              participant.full_name,
              participant.section.name,
              participant.email
            ]
          end
        end
      end
    end

    def generate_individual_assignment_csv
      require "csv"

      CSV.generate(headers: true) do |csv|
        if params[:submission_status] == "submitted"
          # Generate submitted assignments CSV
          csv << [ "Date", "Assignment", "Questions" ]

          @submitted_logs.each do |log|
            csv << [
              log.response_date.strftime("%B %d, %Y"),
              log.assignment.title,
              log.assignment_response_ids.size
            ]
          end
        else
          # Generate not submitted assignments CSV
          csv << [ "Assignment", "Start Date", "End Date", "Status" ]

          @not_submitted_assignments.each do |assignment|
            csv << [
              assignment.title,
              assignment.start_date.strftime("%B %d, %Y"),
              assignment.end_date.strftime("%B %d, %Y"),
              assignment.status
            ]
          end
        end
      end
    end

    def generate_individual_feedback_csv
      require "csv"

      CSV.generate(headers: true) do |csv|
        if params[:submission_status] == "submitted"
          # Generate submitted feedbacks CSV
          csv << [ "Date", "Training Program", "Rating", "Feedback" ]

          @submitted_feedbacks.each do |feedback|
            csv << [
              feedback.created_at.strftime("%B %d, %Y"),
              feedback.training_program.title,
              feedback.rating,
              feedback.content
            ]
          end
        else
          # Generate not submitted training programs CSV
          csv << [ "Training Program", "Start Date", "End Date", "Status" ]

          @not_submitted_training_programs.each do |tp|
            csv << [
              tp.title,
              tp.start_date.strftime("%B %d, %Y"),
              tp.end_date.strftime("%B %d, %Y"),
              tp.status
            ]
          end
        end
      end
    end

    def render_assignment_report_pdf
      submission_status = params[:submission_status] || "submitted"
      report_title = submission_status == "submitted" ? "Submitted Assignments Report" : "Not Submitted Assignments Report"

      # Get filter information for the report header
      date_range_text = case @date_range
      when "today"
                          "Today (#{Date.current.strftime('%b %d, %Y')})"
      when "yesterday"
                          "Yesterday (#{Date.yesterday.strftime('%b %d, %Y')})"
      when "last_7_days"
                          "Last 7 Days"
      when "this_month"
                          "This Month (#{Date.current.strftime('%B %Y')})"
      when "custom"
                          "#{@start_date.strftime('%b %d, %Y')} to #{@end_date.strftime('%b %d, %Y')}"
      else
                          "All Dates"
      end

      section_text = if @section_id.present? && @section_id != "all"
                      section = current_institute.sections.find(@section_id)
                      "Section: #{section.name}"
      else
                      "All Sections"
      end

      assignment_text = if @assignment_id.present? && @assignment_id != "all"
                        assignment = current_institute.assignments.find(@assignment_id)
                        "Assignment: #{assignment.title}"
      else
                        "All Assignments"
      end

      # Generate PDF using Prawn directly
      pdf = generate_assignment_pdf(
        report_title: report_title,
        date_range: date_range_text,
        section: section_text,
        assignment: assignment_text,
        institute_name: current_institute.name,
        submission_status: submission_status
      )

      # Check if the user wants to download or preview
      disposition = params[:download] == "true" ? "attachment" : "inline"

      send_data pdf.render,
        filename: "assignment_report_#{Date.current.strftime('%Y%m%d')}.pdf",
        type: "application/pdf",
        disposition: disposition
    end

    def generate_assignment_pdf(options = {})
      require "prawn"
      require "prawn/table"

      pdf = Prawn::Document.new(
        page_size: "A4",
        margin: [ 30, 30, 30, 30 ],
        info: {
          Title: options[:report_title],
          Author: current_institute.name,
          Subject: "Assignment Report",
          Creator: "Soul ERP",
          CreationDate: Time.now
        }
      )

      # Add logo if present
      if current_institute.respond_to?(:logo) &&
         current_institute.logo.present? &&
         current_institute.logo.respond_to?(:attached?) &&
         current_institute.logo.attached?
        begin
          logo_path = ActiveStorage::Blob.service.path_for(current_institute.logo.key)
          pdf.image logo_path, position: :center, width: 120
        rescue => e
          # Skip logo if it can't be processed
          Rails.logger.warn "Failed to add logo to PDF: #{e.message}"
        end
      end

      # Report header
      pdf.font_size(18) { pdf.text options[:report_title], align: :center, style: :bold }
      pdf.move_down 10

      # Institute info
      pdf.font_size(14) { pdf.text options[:institute_name], align: :center, style: :bold }
      pdf.font_size(10) { pdf.text "Generated on #{Date.current.strftime('%B %d, %Y')}", align: :center, color: "666666" }
      pdf.move_down 20

      # Filter info
      filter_data = [
        [ "Date Range:", options[:date_range] ],
        [ "Section:", options[:section] ],
        [ "Assignment:", options[:assignment] ]
      ]

      pdf.table(filter_data, width: pdf.bounds.width * 0.7, position: :center) do
        cells.borders = []
        column(0).font_style = :bold
        column(0).width = 100
        column(0).align = :right
        column(1).align = :left
        cells.padding = [ 5, 10 ]
      end

      pdf.move_down 20

      # Report data
      if options[:submission_status] == "submitted"
        if @submitted_logs.any?
          # Table header
          header = [ "Date", "Participant", "Section" ]

          # Add assignment column if showing all assignments
          header << "Assignment" if @assignment_id.blank? || @assignment_id == "all"

          header << "Responses"

          # Table data
          data = []
          @submitted_logs.each do |log|
            row = [
              log.response_date.strftime("%b %d, %Y"),
              log.participant.full_name,
              log.participant.section.name
            ]

            row << log.assignment.title if @assignment_id.blank? || @assignment_id == "all"

            row << log.assignment_response_ids.size.to_s

            data << row
          end

          # Generate table
          pdf.table([ header ] + data, header: true, width: pdf.bounds.width) do
            cells.padding = [ 8, 10 ]

            row(0).font_style = :bold
            row(0).background_color = "EEEEEE"

            # Zebra striping
            rows(1..data.length).each_with_index do |row, i|
              row.background_color = "F5F5F5" if i.even?
            end
          end
        else
          pdf.text "No submitted assignments found for the selected criteria.", align: :center, style: :italic, color: "666666"
          pdf.stroke do
            pdf.rectangle [ 0, pdf.cursor ], pdf.bounds.width, 50
          end
        end
      else
        if @not_submitted_participants.any?
          # Table header
          header = [ "Participant", "Section", "Email" ]

          # Add assignment column if specific assignment is selected
          header << "Assignment" if @assignment_id.present? && @assignment_id != "all"

          # Table data
          data = []
          @not_submitted_participants.each do |participant|
            row = [
              participant.full_name,
              participant.section.name,
              participant.email
            ]

            row << @assignment_title if @assignment_id.present? && @assignment_id != "all"

            data << row
          end

          # Generate table
          pdf.table([ header ] + data, header: true, width: pdf.bounds.width) do
            cells.padding = [ 8, 10 ]

            row(0).font_style = :bold
            row(0).background_color = "EEEEEE"

            # Zebra striping
            rows(1..data.length).each_with_index do |row, i|
              row.background_color = "F5F5F5" if i.even?
            end
          end
        else
          pdf.text "No pending submissions found for the selected criteria.", align: :center, style: :italic, color: "666666"
          pdf.stroke do
            pdf.rectangle [ 0, pdf.cursor ], pdf.bounds.width, 50
          end
        end
      end

      # Footer
      pdf.number_pages "Page <page> of <total>",
                       at: [ pdf.bounds.right - 150, 0 ],
                       width: 150,
                       align: :right,
                       size: 9

      # Add footer note
      pdf.go_to_page(pdf.page_count)
      pdf.move_down 10
      pdf.horizontal_rule
      pdf.move_down 5
      pdf.text "This is a system generated report.", align: :center, size: 9, color: "666666"

      pdf
    end

    def render_individual_assignment_report_pdf
      submission_status = params[:submission_status] || "submitted"
      report_title = submission_status == "submitted" ? "Submitted Assignments Report" : "Not Submitted Assignments Report"

      participant = current_institute.participants.find(@participant_id)

      # Get filter information for the report header
      date_range_text = case @date_range
      when "today"
                          "Today (#{Date.current.strftime('%b %d, %Y')})"
      when "yesterday"
                          "Yesterday (#{Date.yesterday.strftime('%b %d, %Y')})"
      when "last_7_days"
                          "Last 7 Days"
      when "this_month"
                          "This Month (#{Date.current.strftime('%B %Y')})"
      when "custom"
                          "#{@start_date.strftime('%b %d, %Y')} to #{@end_date.strftime('%b %d, %Y')}"
      else
                          "All Dates"
      end

      assignment_text = if @assignment_id.present? && @assignment_id != "all"
                        assignment = current_institute.assignments.find(@assignment_id)
                        "Assignment: #{assignment.title}"
      else
                        "All Assignments"
      end

      # Generate PDF using Prawn directly
      pdf = generate_individual_assignment_pdf(
        report_title: "Individual #{report_title} for #{participant.full_name}",
        date_range: date_range_text,
        participant: participant.full_name,
        section: participant.section.name,
        assignment: assignment_text,
        institute_name: current_institute.name,
        submission_status: submission_status
      )

      # Check if the user wants to download or preview
      disposition = params[:download] == "true" ? "attachment" : "inline"

      send_data pdf.render,
        filename: "individual_assignment_report_#{Date.current.strftime('%Y%m%d')}.pdf",
        type: "application/pdf",
        disposition: disposition
    end

    def generate_individual_assignment_pdf(options = {})
      require "prawn"
      require "prawn/table"

      pdf = Prawn::Document.new(
        page_size: "A4",
        margin: [ 30, 30, 30, 30 ],
        info: {
          Title: options[:report_title],
          Author: current_institute.name,
          Subject: "Individual Assignment Report",
          Creator: "Soul ERP",
          CreationDate: Time.now
        }
      )

      # Add logo if present
      if current_institute.respond_to?(:logo) &&
         current_institute.logo.present? &&
         current_institute.logo.respond_to?(:attached?) &&
         current_institute.logo.attached?
        begin
          logo_path = ActiveStorage::Blob.service.path_for(current_institute.logo.key)
          pdf.image logo_path, position: :center, width: 120
        rescue => e
          # Skip logo if it can't be processed
          Rails.logger.warn "Failed to add logo to PDF: #{e.message}"
        end
      end

      # Report header
      pdf.font_size(18) { pdf.text options[:report_title], align: :center, style: :bold }
      pdf.move_down 10

      # Institute info
      pdf.font_size(14) { pdf.text options[:institute_name], align: :center, style: :bold }
      pdf.font_size(10) { pdf.text "Generated on #{Date.current.strftime('%B %d, %Y')}", align: :center, color: "666666" }
      pdf.move_down 20

      # Filter info
      filter_data = [
        [ "Date Range:", options[:date_range] ],
        [ "Participant:", options[:participant] ],
        [ "Section:", options[:section] ],
        [ "Assignment:", options[:assignment] ]
      ]

      pdf.table(filter_data, width: pdf.bounds.width * 0.7, position: :center) do
        cells.borders = []
        column(0).font_style = :bold
        column(0).width = 100
        column(0).align = :right
        column(1).align = :left
        cells.padding = [ 5, 10 ]
      end

      pdf.move_down 20

      # Report data
      if options[:submission_status] == "submitted"
        if @submitted_logs.any?
          # Table header
          header = [ "Date", "Assignment", "Questions" ]

          # Table data
          data = []
          @submitted_logs.each do |log|
            row = [
              log.response_date.strftime("%b %d, %Y"),
              log.assignment.title,
              log.assignment_response_ids.size.to_s
            ]

            data << row
          end

          # Generate table
          pdf.table([ header ] + data, header: true, width: pdf.bounds.width) do
            cells.padding = [ 8, 10 ]

            row(0).font_style = :bold
            row(0).background_color = "EEEEEE"

            # Zebra striping
            rows(1..data.length).each_with_index do |row, i|
              row.background_color = "F5F5F5" if i.even?
            end
          end
        else
          pdf.text "No submitted assignments found for the selected criteria.", align: :center, style: :italic, color: "666666"
          pdf.stroke do
            pdf.rectangle [ 0, pdf.cursor ], pdf.bounds.width, 50
          end
        end
      else
        if @not_submitted_assignments.any?
          # Table header
          header = [ "Assignment", "Start Date", "End Date", "Status" ]

          # Table data
          data = []
          @not_submitted_assignments.each do |assignment|
            row = [
              assignment.title,
              assignment.start_date.strftime("%b %d, %Y"),
              assignment.end_date.strftime("%b %d, %Y"),
              assignment.status
            ]

            data << row
          end

          # Generate table
          pdf.table([ header ] + data, header: true, width: pdf.bounds.width) do
            cells.padding = [ 8, 10 ]

            row(0).font_style = :bold
            row(0).background_color = "EEEEEE"

            # Zebra striping
            rows(1..data.length).each_with_index do |row, i|
              row.background_color = "F5F5F5" if i.even?
            end
          end
        else
          pdf.text "No pending assignments found for the selected criteria.", align: :center, style: :italic, color: "666666"
          pdf.stroke do
            pdf.rectangle [ 0, pdf.cursor ], pdf.bounds.width, 50
          end
        end
      end

      # Footer
      pdf.number_pages "Page <page> of <total>",
                       at: [ pdf.bounds.right - 150, 0 ],
                       width: 150,
                       align: :right,
                       size: 9

      # Add footer note
      pdf.go_to_page(pdf.page_count)
      pdf.move_down 10
      pdf.horizontal_rule
      pdf.move_down 5
      pdf.text "This is a system generated report.", align: :center, size: 9, color: "666666"

      pdf
    end

    def render_section_feedback_report_pdf
      submission_status = params[:submission_status] || "submitted"
      report_title = submission_status == "submitted" ? "Section Feedback Report" : "Not Submitted Section Feedback Report"

      # Get filter information for the report header
      date_range_text = case @date_range
      when "today"
                          "Today (#{Date.current.strftime('%b %d, %Y')})"
      when "yesterday"
                          "Yesterday (#{Date.yesterday.strftime('%b %d, %Y')})"
      when "last_7_days"
                          "Last 7 Days"
      when "this_month"
                          "This Month (#{Date.current.strftime('%B %Y')})"
      when "custom"
                          "#{@start_date.strftime('%b %d, %Y')} to #{@end_date.strftime('%b %d, %Y')}"
      else
                          "All Dates"
      end

      section_text = if @section_id.present? && @section_id != "all"
                      section = current_institute.sections.find(@section_id)
                      "Section: #{section.name}"
      else
                      "All Sections"
      end

      # Generate PDF using Prawn directly
      pdf = generate_section_feedback_pdf(
        report_title: report_title,
        date_range: date_range_text,
        section: section_text,
        institute_name: current_institute.name,
        submission_status: submission_status
      )

      # Check if the user wants to download or preview
      disposition = params[:download] == "true" ? "attachment" : "inline"

      send_data pdf.render,
        filename: "section_feedback_report_#{Date.current.strftime('%Y%m%d')}.pdf",
        type: "application/pdf",
        disposition: disposition
    end

    def generate_section_feedback_pdf(options = {})
      require "prawn"
      require "prawn/table"

      pdf = Prawn::Document.new(
        page_size: "A4",
        margin: [ 30, 30, 30, 30 ],
        info: {
          Title: options[:report_title],
          Author: current_institute.name,
          Subject: "Section Feedback Report",
          Creator: "Soul ERP",
          CreationDate: Time.now
        }
      )

      # Add logo if present
      if current_institute.respond_to?(:logo) &&
         current_institute.logo.present? &&
         current_institute.logo.respond_to?(:attached?) &&
         current_institute.logo.attached?
        begin
          logo_path = ActiveStorage::Blob.service.path_for(current_institute.logo.key)
          pdf.image logo_path, position: :center, width: 120
        rescue => e
          # Skip logo if it can't be processed
          Rails.logger.warn "Failed to add logo to PDF: #{e.message}"
        end
      end

      # Report header
      pdf.font_size(18) { pdf.text options[:report_title], align: :center, style: :bold }
      pdf.move_down 10

      # Institute info
      pdf.font_size(14) { pdf.text options[:institute_name], align: :center, style: :bold }
      pdf.font_size(10) { pdf.text "Generated on #{Date.current.strftime('%B %d, %Y')}", align: :center, color: "666666" }
      pdf.move_down 20

      # Filter info
      filter_data = [
        [ "Date Range:", options[:date_range] ],
        [ "Section:", options[:section] ]
      ]

      pdf.table(filter_data, width: pdf.bounds.width * 0.7, position: :center) do
        cells.borders = []
        column(0).font_style = :bold
        column(0).width = 100
        column(0).align = :right
        column(1).align = :left
        cells.padding = [ 5, 10 ]
      end

      pdf.move_down 20

      # Report data
      if options[:submission_status] == "submitted"
        if @submitted_feedbacks.any?
          # Table header
          header = [ "Date", "Participant", "Section", "Training Program", "Rating", "Content" ]

          # Table data
          data = []
          @submitted_feedbacks.each do |feedback|
            row = [
              feedback.created_at.strftime("%b %d, %Y"),
              feedback.participant.full_name,
              feedback.participant.section.name,
              feedback.training_program.title,
              feedback.rating,
              feedback.content
            ]

            data << row
          end

          # Generate table
          pdf.table([ header ] + data, header: true, width: pdf.bounds.width) do
            cells.padding = [ 8, 10 ]

            row(0).font_style = :bold
            row(0).background_color = "EEEEEE"

            # Zebra striping
            rows(1..data.length).each_with_index do |row, i|
              row.background_color = "F5F5F5" if i.even?
            end
          end
        else
          pdf.text "No submitted feedbacks found for the selected criteria.", align: :center, style: :italic, color: "666666"
          pdf.stroke do
            pdf.rectangle [ 0, pdf.cursor ], pdf.bounds.width, 50
          end
        end
      else
        if @not_submitted_participants.any?
          # Table header
          header = [ "Participant", "Section", "Email" ]

          # Table data
          data = []
          @not_submitted_participants.each do |participant|
            row = [
              participant.full_name,
              participant.section.name,
              participant.email
            ]

            data << row
          end

          # Generate table
          pdf.table([ header ] + data, header: true, width: pdf.bounds.width) do
            cells.padding = [ 8, 10 ]

            row(0).font_style = :bold
            row(0).background_color = "EEEEEE"

            # Zebra striping
            rows(1..data.length).each_with_index do |row, i|
              row.background_color = "F5F5F5" if i.even?
            end
          end
        else
          pdf.text "No pending submissions found for the selected criteria.", align: :center, style: :italic, color: "666666"
          pdf.stroke do
            pdf.rectangle [ 0, pdf.cursor ], pdf.bounds.width, 50
          end
        end
      end

      # Footer
      pdf.number_pages "Page <page> of <total>",
                       at: [ pdf.bounds.right - 150, 0 ],
                       width: 150,
                       align: :right,
                       size: 9

      # Add footer note
      pdf.go_to_page(pdf.page_count)
      pdf.move_down 10
      pdf.horizontal_rule
      pdf.move_down 5
      pdf.text "This is a system generated report.", align: :center, size: 9, color: "666666"

      pdf
    end

    def render_individual_feedback_report_pdf
      submission_status = params[:submission_status] || "submitted"
      report_title = submission_status == "submitted" ? "Individual Feedback Report" : "Not Submitted Individual Feedback Report"

      participant = current_institute.participants.find(@participant_id)

      # Get filter information for the report header
      date_range_text = case @date_range
      when "today"
                          "Today (#{Date.current.strftime('%b %d, %Y')})"
      when "yesterday"
                          "Yesterday (#{Date.yesterday.strftime('%b %d, %Y')})"
      when "last_7_days"
                          "Last 7 Days"
      when "this_month"
                          "This Month (#{Date.current.strftime('%B %Y')})"
      when "custom"
                          "#{@start_date.strftime('%b %d, %Y')} to #{@end_date.strftime('%b %d, %Y')}"
      else
                          "All Dates"
      end

      assignment_text = if @training_program_id.present? && @training_program_id != "all"
                        training_program = current_institute.training_programs.find(@training_program_id)
                        "Training Program: #{training_program.title}"
      else
                        "All Training Programs"
      end

      # Generate PDF using Prawn directly
      pdf = generate_individual_feedback_pdf(
        report_title: report_title,
        date_range: date_range_text,
        participant: participant.full_name,
        section: participant.section.name,
        assignment: assignment_text,
        institute_name: current_institute.name,
        submission_status: submission_status
      )

      # Check if the user wants to download or preview
      disposition = params[:download] == "true" ? "attachment" : "inline"

      send_data pdf.render,
        filename: "individual_feedback_report_#{Date.current.strftime('%Y%m%d')}.pdf",
        type: "application/pdf",
        disposition: disposition
    end

    def generate_individual_certificate(certificate)
      require "prawn"
      require "prawn/table"
      require "gruff"
      require "tempfile"

      participant = certificate.participant
      assignment = certificate.assignment
      config = certificate.certificate_configuration

      # Get the date range for the assignment
      start_date = assignment.start_date.to_date
      end_date = assignment.end_date.to_date

      # Create interval periods based on certificate configuration
      intervals = []
      current_date = start_date

      while current_date <= end_date
        interval_end = [ current_date + config.duration_period.days - 1, end_date ].min
        intervals << [ current_date, interval_end ]
        current_date = interval_end + 1.day
      end

      # Get all responses for this assignment and participant
      responses = AssignmentResponse.where(
        participant: participant,
        assignment: assignment
      ).includes(:question)

      # Group responses by date
      responses_by_date = responses.group_by { |r| r.response_date.to_date }

      # Filter for yes/no and number questions
      yes_no_questions = assignment.questions.where(question_type: "yes_or_no").select(:id, :title, :question_type)
      number_questions = assignment.questions.where(question_type: "number").select(:id, :title, :question_type)

      # Calculate data for the certificate
      table_data = []
      # Truncate question labels for x-axis to avoid overlap
      full_questions = (yes_no_questions + number_questions).map { |q| q.respond_to?(:title) ? q.title : "Question #{q.id}" }
      short_labels = full_questions.map.with_index { |q, i| q.length > 15 ? "Q#{i+1}: #{q[0, 12]}..." : "Q#{i+1}: #{q}" }
      interval_names = intervals.each_with_index.map { |(_s, _e), idx| "#{(idx+1).ordinalize} #{config.duration_period} Days" }

      # Prepare table header
      header = [ "Question" ] + interval_names + [ "Total" ]
      table_data << header

      # Prepare interval data: interval_bars[interval][question_index] = value
      interval_bars = Array.new(intervals.size) { Array.new(full_questions.size, 0) }
      total_per_question = Array.new(full_questions.size, 0)

      (yes_no_questions + number_questions).each_with_index do |question, q_idx|
        row = [ full_questions[q_idx] ]
        total = 0
        intervals.each_with_index do |(interval_start, interval_end), i_idx|
          value = 0
          (interval_start..interval_end).each do |date|
            date_responses = responses_by_date[date] || []
            question_responses = date_responses.select { |r| r.question_id == question.id }
            question_responses.each do |response|
              if question.question_type == "yes_or_no"
                value += 1 if response.answer.to_s.downcase == "yes"
              else
                value += response.answer.to_i if response.answer.present?
              end
            end
          end
          row << value
          interval_bars[i_idx][q_idx] = value
          total += value
        end
        row << total
        total_per_question[q_idx] = total
        table_data << row
      end

      # Calculate available width and height for the chart
      chart_width = 535 # A4 width (595) - left/right margins (30 each)
      chart_height = 0 # Will be set later based on PDF layout

      # Create grouped bar graph: each interval is a series, x-axis is questions
      g = Gruff::Bar.new("#{chart_width}x350") # Initial height, will update below
      g.title = nil # Remove chart title

      g.theme = {
        colors: [
          "#4e73df", "#1cc88a", "#36b9cc", "#f6c23e", "#e74a3b", "#6a5acd", "#20b2aa", "#ff6347", "#ffb347", "#4682b4"
        ],
        marker_color: "#CCCCCC", # lighter axis/grid lines
        background_colors: [ "#ffffff", "#ffffff" ]
      }
      g.hide_legend = false
      g.legend_font_size = 14
      g.marker_font_size = 12
      g.title_font_size = 18
      g.bar_spacing = 0.5
      g.group_spacing = 8

      g.x_axis_label = "Questions"
      g.y_axis_label = "Count"
      g.minimum_value = 0
      g.maximum_value = [ interval_bars.flatten.max, 10 ].max

      interval_names.each_with_index do |iname, i_idx|
        g.data(iname, interval_bars[i_idx])
      end
      g.labels = short_labels.each_with_index.map { |lbl, idx| [ idx, lbl ] }.to_h
      g.hide_line_markers = false # Show axis lines only
      # Gruff shows axis lines by default; grid lines are hidden with hide_line_markers=false
      # Chart width set in Gruff::Bar.new("535x220")
      graph_file = Tempfile.new([ "certificate_graph", ".png" ])
      g.write(graph_file.path)

      # Generate the PDF in memory
      pdf_content = Prawn::Document.new(page_size: "A4", margin: [ 50, 30, 30, 30 ]) do |pdf| # More space at top
        # Draw a subtle border on all pages
        pdf.repeat(:all) do
          pdf.stroke_color "888888"
          pdf.line_width = 1.2
          pdf.stroke_rectangle [ pdf.bounds.left, pdf.bounds.top ], pdf.bounds.width, pdf.bounds.height
        end
        # Set up fonts
        roboto_font_available = true
        font_paths = {
          normal: Rails.root.join("app/assets/fonts/Roboto-Regular.ttf"),
          bold: Rails.root.join("app/assets/fonts/Roboto-Bold.ttf"),
          italic: Rails.root.join("app/assets/fonts/Roboto-Italic.ttf")
        }

        # Check if font files exist
        font_paths.each do |style, path|
          unless File.exist?(path)
            Rails.logger.error "Font file not found: #{path}"
            roboto_font_available = false
          end
        end

        # Initialize fonts
        if roboto_font_available
          pdf.font_families.update(
            "Roboto" => {
              normal: font_paths[:normal],
              bold: font_paths[:bold],
              italic: font_paths[:italic]
            }
          )
          pdf.font "Roboto"
        else
          pdf.font "Helvetica"
        end


        # Colors (black/white/gray theme)
        primary_color = "000000"
        dark_color = "222222"
        border_color = "888888"

        # Header

        # Certificate configuration name at top
        pdf.move_down 20
        pdf.font_size 22
        pdf.fill_color primary_color
        pdf.text (config.name.present? ? config.name.upcase : "CERTIFICATE OF ACHIEVEMENT"), align: :center, style: :bold
        pdf.move_down 8

        # Certificate details
        if config.details.present?
          pdf.font_size 10
          pdf.fill_color "666666"
          pdf.text config.details, align: :center, style: :italic
          pdf.move_down 20
        else
          pdf.move_down 15
        end

        # Participant name
        pdf.font_size 18
        pdf.fill_color dark_color
        pdf.text participant.user.full_name, align: :center, style: :bold
        pdf.move_down 5

        # Section name below participant
        pdf.font_size 11
        pdf.fill_color "555555"
        pdf.text "Section: #{participant.section.name}", align: :center
        pdf.move_down 12

        # Assignment completion details
        pdf.font_size 11
        pdf.fill_color dark_color
        pdf.text "For successfully completing:", align: :center
        pdf.move_down 4
        pdf.font_size 13
        pdf.text assignment.title, align: :center, style: :bold
        pdf.move_down 5
        pdf.font_size 9
        pdf.fill_color "666666"
        pdf.text "Date: #{assignment.start_date.strftime('%B %d, %Y')} - #{assignment.end_date.strftime('%B %d, %Y')}", align: :center
        pdf.move_down 30

        # Draw table first
        if table_data.size > 1
          pdf.font_size 9
          table_width = pdf.bounds.width - 10
          pdf.table table_data, width: table_width, position: :center do |t|
            t.header = true
            t.row(0).font_style = :bold
            t.row(0).background_color = dark_color
            t.row(0).text_color = "FFFFFF"
            t.row(0).min_font_size = 9
            t.row(0).align = :center # Center align all headers
            t.cells.borders = [ :top, :bottom, :left, :right ]
            t.cells.border_width = 0.4
            t.cells.border_color = border_color
            t.cells.padding = [ 6, 2 ] # Slightly smaller row height
            (1...table_data.length).each do |i|
              t.row(i).background_color = i % 2 == 1 ? "F0F0F0" : "FFFFFF"
            end
            t.column(0).font_style = :bold
            t.column(0).width = table_width * 0.32
            t.column(t.column_length - 1).width = 48 # Just enough to fit 'Total' label
            t.column(t.column_length - 1).align = :center
          end
          pdf.move_down 20
        end

        # Calculate available height for the chart (space between here and the footer)
        available_height = pdf.bounds.bottom - pdf.cursor - 260 # 260 for footer and spacing
        chart_height = [ available_height, 250 ].max # Minimum height 250

        # Regenerate the chart with the new height
        chart_width = pdf.bounds.width.to_i
        g = Gruff::Bar.new("#{chart_width}x#{chart_height}")
        g.title = nil
        g.theme = {
          colors: [
            "#4e73df", "#1cc88a", "#36b9cc", "#f6c23e", "#e74a3b", "#6a5acd", "#20b2aa", "#ff6347", "#ffb347", "#4682b4"
          ],
          marker_color: "#CCCCCC",
          background_colors: [ "#ffffff", "#ffffff" ]
        }
        g.hide_legend = false
        g.legend_font_size = 12
        g.marker_font_size = 10
        g.title_font_size = 14
        g.x_axis_label_font_size = 12 if g.respond_to?(:x_axis_label_font_size=)
        g.y_axis_label_font_size = 12 if g.respond_to?(:y_axis_label_font_size=)
        g.bar_spacing = 0.5
        g.group_spacing = 8
        g.x_axis_label = "Questions"
        g.y_axis_label = "Count"
        g.minimum_value = 0
        g.maximum_value = [ interval_bars.flatten.max, 10 ].max
        interval_names.each_with_index do |iname, i_idx|
          g.data(iname, interval_bars[i_idx])
        end
        g.labels = short_labels.each_with_index.map { |lbl, idx| [ idx, lbl ] }.to_h
        g.hide_line_markers = false
        graph_file = Tempfile.new([ "certificate_graph", ".png" ])
        g.write(graph_file.path)

        # Draw chart below table, using all available space
        if File.exist?(graph_file.path)
          pdf.image graph_file.path, fit: [ pdf.bounds.width, chart_height ], position: :center
          pdf.move_down 10
        end

        pdf.move_down 240
        # (Removed question key section)

        # Footer - positioned at rock bottom of page
        pdf.go_to_page(pdf.page_count)

        # Position footer at the absolute bottom (just above bottom margin)
        # Bottom margin is typically 36, so position at y=28 for rock bottom
        pdf.bounding_box([ 0, 28 ], width: pdf.bounds.width, height: 25) do
          # Add horizontal line separator
          pdf.stroke_color border_color
          pdf.horizontal_rule
          pdf.move_down 5

          # Footer text from configuration
          if config.certificate_left_footer.present? || config.certificate_right_footer.present?
            footer_table_data = []

            # Create a two-column layout for footer
            left_footer = config.certificate_left_footer.present? ? config.certificate_left_footer : ""
            right_footer = config.certificate_right_footer.present? ? config.certificate_right_footer : ""

            footer_table_data << [ left_footer, right_footer ]

            pdf.font_size 9
            pdf.fill_color "555555"
            pdf.table footer_table_data, width: pdf.bounds.width, cell_style: { borders: [], padding: [ 0, 5 ] } do |t|
              t.column(0).align = :left
              t.column(1).align = :right
            end
          end
        end
      end

      # Clean up temp file
      graph_file.close
      graph_file.unlink

      # Update certificate timestamp without storing file
      certificate.update(generated_at: Time.current)

      # Return the PDF content
      pdf_content.render
    rescue => e
      Rails.logger.error "Error generating certificate: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      certificate.errors.add(:base, "Certificate generation failed: #{e.message}")
      nil
    end

    # Close generate_individual_certificate method

    # `view_section_certificates` removed — section-based viewing consolidated into `view_certificates`
  end
end
