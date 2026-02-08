module InstituteAdmin
  class GeneralSettingsController < ApplicationController
    layout "institute_admin"

    before_action :authenticate_user!
    before_action :check_admin_access
    before_action :set_institute

    def index
      # Just render the form with the current institute
    end

    def update
      if @institute.update(institute_params)
        redirect_to institute_admin_general_settings_path, notice: "Institute settings were successfully updated."
      else
        flash.now[:alert] = "Unable to update institute settings."
        render :index, status: :unprocessable_entity
      end
    end

    private

    def check_admin_access
      unless current_user.is_a?(User) && current_user.institute_admin?
        redirect_to root_path, alert: "You must be an institute admin to access this area."
      end
    end

    def set_institute
      @institute = current_user.institute
    end

    def institute_params
      params.require(:institute).permit(:name, :code, :description, :address,
                                        :contact_number, :email, :active,
                                        :registered_poc, :service_started_on, :owner_name,
                                        :age_of_service, :billing_type, :expiry_date,
                                        :other_details)
      # Note: institution_type is intentionally excluded as requested
    end
  end
end
