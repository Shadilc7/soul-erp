module ApplicationHelper
  def active_link?(controller_name)
    case controller_name
    when "dashboard"
      controller.controller_name == "dashboard" ||
      (controller.controller_name == "admin" && controller.action_name == "dashboard")
    when "sections"
      controller.controller_name == "sections"
    when "trainers"
      controller.controller_name == "trainers"
    when "participants"
      controller.controller_name == "participants"
    when "questions"
      controller.controller_name == "questions"
    when "training_programs"
      controller.controller_name == "training_programs"
    when "attendances"
      controller.controller_name == "attendances"
    when "institutes"
      controller.controller_name == "institutes"
    when "users"
      controller.controller_name == "users"
    when "registration_settings"
      controller.controller_name == "registration_settings"
    when "assignments"
      controller.controller_name == "assignments"
    when "profile"
      controller.controller_name == "profile"
    else
      false
    end
  end

  def bootstrap_class_for_flash(flash_type)
    case flash_type.to_sym
    when :success
      "success"
    when :error
      "danger"
    when :alert
      "warning"
    when :notice
      "info"
    else
      flash_type.to_s
    end
  end
end
