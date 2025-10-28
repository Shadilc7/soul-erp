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

      # Feedback statistics
      calculate_feedback_statistics

      # Training program feedback data
      @program_feedback_data = get_program_feedback_data

      # Recent training programs
      @recent_programs = current_institute.training_programs
        .includes(:participants, :training_program_feedbacks)
        .order(created_at: :desc)
        .limit(5)
        .map do |program|
          program.define_singleton_method(:feedback_percentage) do
            total_participants = self.participants.count
            return 0 if total_participants.zero?

            received_feedback = self.training_program_feedbacks.count
            ((received_feedback.to_f / total_participants) * 100).round
          end

          program.define_singleton_method(:participants_count) do
            self.participants.count
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

        total_possible_feedback = current_institute.training_programs.sum do |program|
          program.participants.count
        end

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
                    .includes(:participants, :training_program_feedbacks)
                    .limit(10)

        result = programs.map do |program|
          total_participants = program.participants.count
          received_feedback = program.training_program_feedbacks.count
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
