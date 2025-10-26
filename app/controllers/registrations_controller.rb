class RegistrationsController < Devise::RegistrationsController
  before_action :configure_sign_up_params, only: [ :create ]
  before_action :set_sections_and_institutes, only: [ :new, :create ]

  def new
    build_resource({})
    resource.build_participant

    # Get registration setting, handle case when database is fresh
    registration_setting = RegistrationSetting.instance
    enabled_institute_ids = registration_setting&.enabled_institutes || []

    @institutes = Institute.active.where(id: enabled_institute_ids)
    respond_with resource
  end

  def create
    build_resource(sign_up_params)
    resource.role = :participant

    # Set the institute_id from participant's institute_id
    if params[:user][:participant_attributes][:institute_id].present?
      resource.institute_id = params[:user][:participant_attributes][:institute_id]
    end

    if resource.save
      # Since all new accounts are inactive, we'll always show the pending approval message
      redirect_to new_user_session_path,
        notice: "Registration successful! Your account is pending for approval."
    else
      clean_up_passwords resource
      set_minimum_password_length
      # Re-fetch institutes and sections for the form
      set_sections_and_institutes
      respond_with resource
    end
  end

  protected

  def configure_sign_up_params
    devise_parameter_sanitizer.permit(:sign_up, keys: [
      :first_name,
      :last_name,
      :email,
      participant_attributes: [
        :phone_number,
        :date_of_birth,
        :institute_id,
        :section_id,
        :participant_type,
        :address,
        :pin_code,
        :district,
        :state
      ]
    ])
  end

  def build_resource(hash = {})
    super
    resource.role = :participant
    resource.active = false
    resource.build_participant if resource.participant.nil?
    resource.participant.enrollment_date = Date.current if resource.participant
  end

  private

  def set_sections_and_institutes
    @institutes = Institute.active
    @sections = Section.active
  end
end
