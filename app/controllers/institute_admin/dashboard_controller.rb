module InstituteAdmin
  class DashboardController < InstituteAdmin::BaseController
    def index
      # Total counts
      @total_participants = current_institute.participants.count
  # Today's assignment responses count for this institute
  # Count distinct (assignment_id, participant_id) so multiple answers from same participant for
  # the same assignment on the same day are counted once.
  @today_responses_count = AssignmentResponse.joins(:participant)
            .where(participants: { institute_id: current_institute.id }, response_date: Date.current)
            .count("DISTINCT (assignment_responses.assignment_id, assignment_responses.participant_id)")
      @active_participants = current_institute.participants.active.count
      @total_trainers = current_institute.trainers.count
      @active_trainers = current_institute.active_trainers_count
      @total_sections = current_institute.sections.count
      @active_sections = current_institute.sections.active.count
      @total_questions = current_institute.questions.count
      @total_question_sets = current_institute.question_sets.count
      @total_assignments = current_institute.assignments.count
      @total_training_programs = current_institute.training_programs.count
      begin
  # Use AssignmentResponse as the base and LEFT JOIN assignments so we include responses
  # even if the assignment record is missing/soft-deleted. COALESCE the title for display.
  # Use Arel.sql to safely include raw SQL expressions (COALESCE and COUNT DISTINCT)
  assignment_counts = AssignmentResponse.joins(:participant)
        .left_joins(:assignment)
        .where(participants: { institute_id: current_institute.id }, response_date: Date.current)
        .group("assignments.id", Arel.sql("COALESCE(assignments.title, 'Deleted Assignment')"))
        .order(Arel.sql("COUNT(DISTINCT assignment_responses.participant_id) DESC"))
        .limit(10)
        .pluck(Arel.sql("COALESCE(assignments.title, 'Deleted Assignment')"), Arel.sql("COUNT(DISTINCT assignment_responses.participant_id)"))

        @assignment_labels = assignment_counts.map { |t, _| t || "Untitled" }
        @assignment_data = assignment_counts.map { |_, c| c }

        # If no data found, log a helpful debug message
        if @assignment_data.blank?
          Rails.logger.info "Submissions by Assignment: no results for institute=#{current_institute.id} date=#{Date.current} (assignment_counts empty)"
        end
      rescue => e
        Rails.logger.error "Error preparing submissions by assignment data: #{e.message}"
        @assignment_labels = []
        @assignment_data = []
      end

      # Submissions by Section (today) - count distinct (assignment_id, participant_id) per section
      begin
  section_counts = AssignmentResponse.joins(participant: :section)
        .where(participants: { institute_id: current_institute.id }, response_date: Date.current)
        .group("sections.id", "sections.name")
        .order(Arel.sql("COUNT(DISTINCT (assignment_responses.assignment_id, assignment_responses.participant_id)) DESC"))
        .limit(10)
        .pluck("sections.name", Arel.sql("COUNT(DISTINCT (assignment_responses.assignment_id, assignment_responses.participant_id))"))

        @submissions_section_labels = section_counts.map { |t, _| t || "No Section" }
        @submissions_section_data = section_counts.map { |_, c| c }
      rescue => e
        Rails.logger.error "Error preparing submissions by section data: #{e.message}"
        @submissions_section_labels = []
        @submissions_section_data = []
      end

      # ...completion rate chart removed

      # Not-submitted by Assignment (Top 10)
      begin
        date = Date.current
        institute_id = current_institute.id

        assignments_sql = <<-SQL
          SELECT a.id, a.title,
            COUNT(DISTINCT p.id) AS expected_count,
            COALESCE(cc.completed_count, 0) AS completed_count,
            (COUNT(DISTINCT p.id) - COALESCE(cc.completed_count, 0)) AS pending_count
          FROM assignments a
          LEFT JOIN assignment_participants ap ON ap.assignment_id = a.id
          LEFT JOIN assignment_sections asg ON asg.assignment_id = a.id
          LEFT JOIN participants p ON (ap.participant_id = p.id OR p.section_id = asg.section_id)
          LEFT JOIN users u ON u.id = p.user_id AND u.active = true
          LEFT JOIN (
            SELECT assignment_id, COUNT(DISTINCT participant_id) AS completed_count
            FROM assignment_response_logs
            WHERE response_date = '#{date}' AND institute_id = #{institute_id}
            GROUP BY assignment_id
          ) cc ON cc.assignment_id = a.id
          WHERE a.active = true
            AND DATE(a.start_date) <= '#{date}' AND DATE(a.end_date) >= '#{date}'
            AND p.institute_id = #{institute_id}
          GROUP BY a.id, a.title, cc.completed_count
          HAVING (COUNT(DISTINCT p.id) - COALESCE(cc.completed_count, 0)) > 0
          ORDER BY pending_count DESC
          LIMIT 10
        SQL

        rows = ActiveRecord::Base.connection.exec_query(assignments_sql).to_a
        @not_submitted_assignment_labels = rows.map { |r| r["title"] }
        @not_submitted_assignment_data = rows.map { |r| r["pending_count"].to_i }
      rescue => e
        Rails.logger.error "Error preparing not-submitted-by-assignment data: #{e.message}"
        @not_submitted_assignment_labels = []
        @not_submitted_assignment_data = []
      end

      # Pending by Section (today)
      begin
        date = Date.current
        institute_id = current_institute.id
        sections_sql = <<-SQL
          SELECT s.id, s.name,
            COUNT(DISTINCT p.id) AS expected_count,
            COALESCE(sc.completed_count, 0) AS completed_count,
            (COUNT(DISTINCT p.id) - COALESCE(sc.completed_count, 0)) AS pending_count
          FROM sections s
          JOIN participants p ON p.section_id = s.id
          LEFT JOIN assignment_sections asg ON asg.section_id = s.id
          LEFT JOIN assignments a ON a.id = asg.assignment_id
          LEFT JOIN users u ON u.id = p.user_id AND u.active = true
          LEFT JOIN (
            SELECT participant_id, COUNT(DISTINCT assignment_id) AS completed_count, NULL as section_id
            FROM assignment_response_logs
            WHERE response_date = '#{date}' AND institute_id = #{institute_id}
            GROUP BY participant_id
          ) sc ON sc.participant_id = p.id
          WHERE p.institute_id = #{institute_id}
            AND a.active = true
            AND DATE(a.start_date) <= '#{date}' AND DATE(a.end_date) >= '#{date}'
          GROUP BY s.id, s.name, sc.completed_count
          HAVING (COUNT(DISTINCT p.id) - COALESCE(sc.completed_count, 0)) > 0
          ORDER BY pending_count DESC
          LIMIT 10
        SQL

        sec_rows = ActiveRecord::Base.connection.exec_query(sections_sql).to_a
        if sec_rows.blank?
          # Fallback method: compute expected per section from participants and subtract completed per section
          begin
            sections = current_institute.sections
                        .joins(:participants)
                        .where(participants: { institute_id: institute_id })
                        .select("sections.id, sections.name, COUNT(DISTINCT participants.id) as expected_count")
                        .group("sections.id, sections.name")

            completed_by_section = AssignmentResponse.joins(:participant)
                                     .where(response_date: date, participants: { institute_id: institute_id })
                                     .group("participants.section_id")
                                     .count("DISTINCT (assignment_responses.assignment_id, assignment_responses.participant_id)")

            @pending_section_labels = []
            @pending_section_data = []
            sections.each do |s|
              expected = s.expected_count.to_i
              completed = completed_by_section[s.id] || 0
              pending = [ expected - completed, 0 ].max
              if pending > 0
                @pending_section_labels << s.name
                @pending_section_data << pending
              end
            end
            # keep only top 10 by pending
            if @pending_section_labels.present?
              combined = @pending_section_labels.zip(@pending_section_data)
              combined = combined.sort_by { |_, v| -v }[0, 10]
              @pending_section_labels, @pending_section_data = combined.map(&:first), combined.map(&:last)
            end
          rescue => fb_e
            Rails.logger.error "Fallback preparing pending-by-section failed: #{fb_e.message}"
            @pending_section_labels = []
            @pending_section_data = []
          end
        else
          @pending_section_labels = sec_rows.map { |r| r["name"] }
          @pending_section_data = sec_rows.map { |r| r["pending_count"].to_i }
        end
      rescue => e
        Rails.logger.error "Error preparing pending-by-section data: #{e.message}"
        @pending_section_labels = []
        @pending_section_data = []
      end

      # Backlog trend (last 14 days) - pending totals per day
      begin
        date_range = (Date.current - 13)..Date.current
        backlog_labels = []
        backlog_data = []
        date_range.each do |d|
          # expected pairs
          expected_q = ActiveRecord::Base.connection.exec_query(<<-SQL, "SQL")
            SELECT COUNT(DISTINCT (a.id, p.id)) AS expected_count
            FROM assignments a
            LEFT JOIN assignment_participants ap ON ap.assignment_id = a.id
            LEFT JOIN assignment_sections asg ON asg.assignment_id = a.id
            LEFT JOIN participants p ON (ap.participant_id = p.id OR p.section_id = asg.section_id)
            LEFT JOIN users u ON u.id = p.user_id
            WHERE a.active = true
              AND DATE(a.start_date) <= '#{d}' AND DATE(a.end_date) >= '#{d}'
              AND p.institute_id = #{institute_id} AND u.active = true
          SQL
          expected = expected_q.rows.present? ? expected_q.rows.first.first.to_i : 0

          completed_q = ActiveRecord::Base.connection.exec_query(<<-SQL, "SQL")
            SELECT COUNT(DISTINCT (assignment_id, participant_id)) AS completed_count
            FROM assignment_response_logs
            WHERE institute_id = #{institute_id} AND response_date = '#{d}'
          SQL
          completed = completed_q.rows.present? ? completed_q.rows.first.first.to_i : 0

          backlog_labels << d.strftime("%b %d")
          backlog_data << [ expected - completed, 0 ].max
        end

        @backlog_labels = backlog_labels
        @backlog_data = backlog_data
      rescue => e
        Rails.logger.error "Error preparing backlog trend data: #{e.message}"
        @backlog_labels = []
        @backlog_data = []
      end

      # Section-wise participant data
      section_data = current_institute.sections.active
        .select("sections.name, sections.capacity, COUNT(DISTINCT participants.id) as participant_count")
        .joins("LEFT JOIN participants ON participants.section_id = sections.id")
        .joins("LEFT JOIN users ON users.id = participants.user_id")
        .where(users: { active: true })
        .group("sections.id, sections.name, sections.capacity")
        .order("sections.name")

      @section_labels = section_data.map(&:name)
      @section_data = {
        participants: section_data.map(&:participant_count),
        capacity: section_data.map(&:capacity)
      }

      # If no section data, provide default empty arrays
      if @section_labels.empty?
        @section_labels = []
        @section_data = { participants: [], capacity: [] }
      end

      # Participant type data
      participant_types = current_institute.participants
        .joins(:user)
        .where(users: { active: true })
        .group(:participant_type)
        .count

      @type_labels = [ "Student", "Guardian", "Employee" ]
      @type_data = @type_labels.map { |type| participant_types[type.downcase] || 0 }

      # Training program statistics
      @active_programs_count = current_institute.training_programs.where(status: :ongoing).count
      @active_programs_percentage = calculate_percentage(@active_programs_count, @total_training_programs)

      # Submissions over time (last 14 days) - count distinct (assignment, participant) per day
      begin
        date_range = (Date.current - 13)..Date.current
        submissions_by_date = AssignmentResponse.joins(:participant)
                                .where(participants: { institute_id: current_institute.id }, response_date: date_range)
                                .group(:response_date)
                                .count("DISTINCT (assignment_responses.assignment_id, assignment_responses.participant_id)")

        @submissions_time_labels = date_range.map { |d| d.strftime("%b %d") }
        @submissions_time_data = date_range.map { |d| submissions_by_date[d] || 0 }
      rescue => e
        Rails.logger.error "Error preparing submissions over time data: #{e.message}"
        @submissions_time_labels = []
        @submissions_time_data = []
      end

      # Feedback statistics
      calculate_feedback_statistics

      # Training program feedback data
      @program_feedback_data = get_program_feedback_data

      # Recent training programs
      @recent_programs = current_institute.training_programs
        .left_joins(:training_program_participants)
        .select("training_programs.*, COUNT(training_program_participants.id) AS participants_count")
        .group("training_programs.id")
        .order(created_at: :desc)
        .limit(5)
        .map do |program|
          program.define_singleton_method(:feedback_percentage) do
            total_participants = self[:participants_count].to_i
            return 0 if total_participants.zero?

            received_feedback = self.training_program_feedbacks_count.to_i
            ((received_feedback.to_f / total_participants) * 100).round
          end

          program.define_singleton_method(:participants_count) do
            self[:participants_count].to_i
          end

          program
        end
    end

    private

    def calculate_feedback_statistics
      begin
        # Get all feedback through training programs
        @total_feedback_received = TrainingProgramFeedback.joins(:training_program)
                                    .where(training_programs: { institute_id: current_institute.id })
                                    .count

        total_possible_feedback = TrainingProgramParticipant
          .joins(:training_program)
          .where(training_programs: { institute_id: current_institute.id })
          .count

        @total_feedback_pending = total_possible_feedback - @total_feedback_received
        @feedback_received_percentage = calculate_percentage(@total_feedback_received, total_possible_feedback)
        @feedback_pending_percentage = calculate_percentage(@total_feedback_pending, total_possible_feedback)
      rescue => e
        Rails.logger.error "Error calculating feedback statistics: #{e.message}"
        @total_feedback_received = 0
        @total_feedback_pending = 0
        @feedback_received_percentage = 0
        @feedback_pending_percentage = 0
      end
    end

    def get_program_feedback_data
      begin
        programs = current_institute.training_programs
                    .left_joins(:training_program_participants)
                    .select("training_programs.*, COUNT(training_program_participants.id) AS participants_count")
                    .group("training_programs.id")
                    .limit(10)

        result = programs.map do |program|
          total_participants = program[:participants_count].to_i
          received_feedback = program.training_program_feedbacks_count.to_i
          pending_feedback = [ total_participants - received_feedback, 0 ].max

          {
            name: program.title || "Unnamed Program",
            received: received_feedback,
            pending: pending_feedback,
            total: total_participants
          }
        end

        # Return empty array if no programs with feedback
        return [] if result.all? { |r| r[:received] == 0 && r[:pending] == 0 }

        result
      rescue => e
        Rails.logger.error "Error getting program feedback data: #{e.message}"
        []
      end
    end

    def calculate_percentage(part, total)
      return 0 if total.nil? || total.zero?
      ((part.to_f / total) * 100).round
    end
  end
end
