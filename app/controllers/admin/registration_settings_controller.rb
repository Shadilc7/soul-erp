module Admin
  class RegistrationSettingsController < AdminController
    def edit
      @registration_setting = RegistrationSetting.instance
      @institutes = Institute.active
    end

    def update
      @registration_setting = RegistrationSetting.instance

      # Convert enabled_institutes to integers or set to empty array if none selected
      if params[:registration_setting] && params[:registration_setting][:enabled_institutes].present?
        params[:registration_setting][:enabled_institutes].reject!(&:blank?)
        params[:registration_setting][:enabled_institutes].map!(&:to_i)
      else
        params[:registration_setting] ||= {}
        params[:registration_setting][:enabled_institutes] = []
      end

      if @registration_setting.update(registration_setting_params)
        redirect_to edit_admin_registration_setting_path,
          notice: "Registration settings updated successfully."
      else
        @institutes = Institute.active
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def registration_setting_params
      params.require(:registration_setting).permit(enabled_institutes: [])
    end
  end
end
