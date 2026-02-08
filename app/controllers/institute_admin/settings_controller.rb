module InstituteAdmin
  class SettingsController < ApplicationController
    layout "institute_admin"

    before_action :authenticate_user!
    before_action :check_admin_access

    def index
      # This is the main settings page that will show navigation to various settings
    end

    private

    def check_admin_access
      unless current_user.is_a?(User) && current_user.institute_admin?
        redirect_to root_path, alert: "You must be an institute admin to access this area."
      end
    end
  end
end
