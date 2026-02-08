module InstituteAdmin
  module AttendancesHelper
    def status_color(status)
      case status
      when "present"
        "success"
      when "absent"
        "danger"
      when "late"
        "warning"
      else
        "secondary"
      end
    end
  end
end
