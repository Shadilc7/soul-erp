module TrainerPortal
  class AttendancesController < TrainerPortal::BaseController
    before_action :set_training_program, except: [ :index, :list ]
    before_action :set_date, only: [ :mark, :record, :edit, :update, :check_status ]
    before_action :set_participants, only: [ :mark, :record, :edit, :update, :history, :check_status ]

    def index
      @training_programs = current_trainer.training_programs
        .includes(:section, participant: :user)
        .order(status: :asc, created_at: :desc)
    end

    def list
      @training_programs = current_trainer.training_programs
        .includes(:section, participant: :user)
        .order(status: :asc, created_at: :desc)

      # Get today's date
      @today = Date.today

      # For each program, check if attendance is marked for today
      @attendance_status = {}
      @training_programs.each do |program|
        @attendance_status[program.id] = {
          marked_today: program.attendance_marked?(@today),
          total_days_marked: program.attendances.select(:date).distinct.count,
          total_participants: program.all_participants.count,
          start_date: program.start_date,
          end_date: program.end_date,
          active: program.ongoing?
        }
      end
    end

    def mark
      # Check if the program is completed
      if @training_program.completed?
        redirect_to trainer_portal_attendances_path,
          alert: "Cannot mark attendance for completed programs"
        return
      end

      # Check if attendance has already been marked for this date
      if Attendance.exists?(training_program: @training_program, date: @date)
        redirect_to edit_trainer_portal_attendance_path(@training_program, date: @date)
        return
      end

      # Get participants for the training program
      @attendance_records = []
    end

    def record
      # Create attendance records for all participants
      ActiveRecord::Base.transaction do
        attendance_params[:attendances].each do |participant_id, status|
          @training_program.attendances.create!(
            participant_id: participant_id,
            date: @date,
            status: status,
            marked_by: current_user
          )
        end

        redirect_to history_trainer_portal_attendance_path(@training_program),
          notice: "Attendance marked successfully for #{@date.strftime('%B %d, %Y')}"
      end
    rescue ActiveRecord::RecordInvalid => e
      redirect_to mark_trainer_portal_attendance_path(@training_program, date: @date),
        alert: "Error marking attendance: #{e.message}"
    end

    def edit
      # Check if attendance has been marked for this date
      unless @training_program.attendance_marked?(@date)
        flash.now[:alert] = "No attendance record found for #{@date.strftime('%B %d, %Y')}. You can mark attendance below."
        @attendance_records = []
        render :mark, status: :unprocessable_entity
        return
      end

      @participants = @training_program.all_participants
      @attendance_records = @training_program.attendances.by_date(@date).index_by(&:participant_id)
    end

    def update
      # Update attendance records for all participants
      ActiveRecord::Base.transaction do
        attendance_params[:attendances].each do |participant_id, status|
          attendance = @training_program.attendances.find_or_initialize_by(
            participant_id: participant_id,
            date: @date
          )

          # Set marked_by if it's a new record
          attendance.marked_by = current_user if attendance.new_record?

          attendance.status = status
          attendance.save!
        end

        redirect_to history_trainer_portal_attendance_path(@training_program),
          notice: "Attendance updated successfully for #{@date.strftime('%B %d, %Y')}"
      end
    rescue ActiveRecord::RecordInvalid => e
      redirect_to edit_trainer_portal_attendance_path(@training_program, date: @date),
        alert: "Error updating attendance: #{e.message}"
    end

    def history
      # Get all distinct dates for which attendance has been marked
      @attendance_dates = @training_program.attendances
        .select(:date)
        .distinct
        .order(date: :asc)
        .pluck(:date)

      @participants = @training_program.all_participants.includes(:user)

      # Create a hash of attendance records by date and participant
      @attendance_records = {}

      @attendance_dates.each do |date|
        @attendance_records[date] = @training_program.attendances
          .where(date: date)
          .includes(:participant)
          .index_by(&:participant_id)
      end
    end

    def check_status
      # Get all attendance dates for this training program
      @attendance_dates = @training_program.attendances
        .select(:date)
        .distinct
        .order(date: :desc)
        .pluck(:date)

      # Calculate attendance statistics for each participant
      @attendance_stats = {}

      @participants.each do |participant|
        stats = {
          present: Attendance.where(training_program: @training_program, participant: participant, status: :present).count,
          late: Attendance.where(training_program: @training_program, participant: participant, status: :late).count,
          absent: Attendance.where(training_program: @training_program, participant: participant, status: :absent).count,
          excused: Attendance.where(training_program: @training_program, participant: participant, status: :excused).count
        }
        @attendance_stats[participant.id] = stats
      end

      # If this is an AJAX request, return JSON
      if request.xhr?
        is_marked = @training_program.attendance_marked?(@date)
        edit_url = is_marked ? edit_trainer_portal_attendance_path(@training_program, date: @date) : nil

        Rails.logger.debug "AJAX Request: date=#{@date}, marked=#{is_marked}, edit_url=#{edit_url}"

        render json: {
          marked: is_marked,
          edit_url: edit_url
        }
      end
    end

    def export_history_csv
      @training_program = current_trainer.training_programs.find(params[:training_program_id])

      # Get all distinct dates for which attendance has been marked
      @attendance_dates = @training_program.attendances
        .select(:date)
        .distinct
        .order(date: :asc)
        .pluck(:date)

      @participants = @training_program.all_participants.includes(:user)

      # Create a hash of attendance records by date and participant
      @attendance_records = {}

      @attendance_dates.each do |date|
        @attendance_records[date] = @training_program.attendances
          .where(date: date)
          .includes(:participant)
          .index_by(&:participant_id)
      end

      respond_to do |format|
        format.csv do
          response.headers["Content-Type"] = "text/csv"
          response.headers["Content-Disposition"] = "attachment; filename=attendance_history_#{@training_program.id}_#{Date.today.strftime('%Y%m%d')}.csv"
          render template: "trainer_portal/attendances/export_history_csv"
        end
      end
    end

    def export_status_csv
      @training_program = current_trainer.training_programs.find(params[:training_program_id])
      @participants = @training_program.all_participants.includes(:user)

      # Calculate attendance statistics for each participant
      @attendance_stats = {}

      @participants.each do |participant|
        stats = {
          present: Attendance.where(training_program: @training_program, participant: participant, status: :present).count,
          late: Attendance.where(training_program: @training_program, participant: participant, status: :late).count,
          absent: Attendance.where(training_program: @training_program, participant: participant, status: :absent).count,
          excused: Attendance.where(training_program: @training_program, participant: participant, status: :excused).count
        }
        @attendance_stats[participant.id] = stats
      end

      respond_to do |format|
        format.csv do
          response.headers["Content-Type"] = "text/csv"
          response.headers["Content-Disposition"] = "attachment; filename=attendance_status_#{@training_program.id}_#{Date.today.strftime('%Y%m%d')}.csv"
          render template: "trainer_portal/attendances/export_status_csv"
        end
      end
    end

    private

    def set_training_program
      @training_program = current_trainer.training_programs.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      redirect_to trainer_portal_attendances_path, alert: "Training program not found."
    end

    def set_date
      @date = params[:date].present? ? Date.parse(params[:date]) : Date.today
    rescue Date::Error
      redirect_to trainer_portal_attendances_path, alert: "Invalid date format."
    end

    def set_participants
      @participants = @training_program.all_participants.to_a
    end

    def attendance_params
      params.require(:attendance).permit(attendances: {})
    end
  end
end
