class InstituteAdmin::CertificateConfigurationsController < InstituteAdmin::BaseController
  before_action :set_certificate_configuration, only: [ :show, :edit, :update, :destroy ]
  before_action :set_active_section

  def index
    @certificate_configurations = current_institute.certificate_configurations.order(created_at: :desc)
  end

  def show
  end

  def new
    @certificate_configuration = current_institute.certificate_configurations.build
  end

  def edit
  end

  def create
    @certificate_configuration = current_institute.certificate_configurations.build(certificate_configuration_params)

    if @certificate_configuration.save
      redirect_to institute_admin_certificate_configurations_path, notice: "Certificate configuration was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @certificate_configuration.update(certificate_configuration_params)
      redirect_to institute_admin_certificate_configurations_path, notice: "Certificate configuration was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @certificate_configuration.destroy
    redirect_to institute_admin_certificate_configurations_path, notice: "Certificate configuration was successfully deleted."
  end

  private

  def set_certificate_configuration
    @certificate_configuration = current_institute.certificate_configurations.find(params[:id])
  end

  def certificate_configuration_params
    params.require(:certificate_configuration).permit(:name, :details, :duration_period, :status, :eligible_criteria, :certificate_left_footer, :certificate_right_footer)
  end

  def set_active_section
    @active_section = "reports"
  end
end
