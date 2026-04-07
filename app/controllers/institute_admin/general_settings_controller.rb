module InstituteAdmin
  class GeneralSettingsController < InstituteAdmin::BaseController
    before_action :set_institute

    def index
      # Just render the form with the current institute
    end

    def update
      permitted = institute_params
      if permitted.delete(:remove_logo) == "1"
        @institute.logo.purge
      end
      if @institute.update(permitted)
        redirect_to institute_admin_general_settings_path, notice: "Institute settings were successfully updated."
      else
        flash.now[:alert] = "Unable to update institute settings."
        render :index, status: :unprocessable_entity
      end
    end

    private

    def set_institute
      @institute = current_institute
    end

    def institute_params
      params.require(:institute).permit(:name, :code, :description, :address,
                                        :contact_number, :email, :active,
                                        :registered_poc, :service_started_on, :owner_name,
                                        :age_of_service, :billing_type, :expiry_date,
                                        :other_details, :logo, :remove_logo)
      # Note: institution_type is intentionally excluded as requested
    end
  end
end
