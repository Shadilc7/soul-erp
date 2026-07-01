require "test_helper"

class InstituteAdmin::CertificateConfigurationsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @admin = users(:one)
    @institute = @admin.institute
    @certificate_configuration = certificate_configurations(:one)
    sign_in @admin
  end

  test "should get index" do
    get institute_admin_certificate_configurations_url
    assert_response :success
  end

  test "should get new" do
    get new_institute_admin_certificate_configuration_url
    assert_response :success
  end

  test "should create certificate_configuration" do
    assert_difference("CertificateConfiguration.count") do
      post institute_admin_certificate_configurations_url, params: {
        certificate_configuration: {
          name: "New Config",
          details: "Some details",
          duration_period: 10,
          status: "active"
        }
      }
    end
    assert_redirected_to institute_admin_certificate_configurations_path
  end

  test "should get edit" do
    get edit_institute_admin_certificate_configuration_url(@certificate_configuration)
    assert_response :success
  end

  test "should update certificate_configuration" do
    patch institute_admin_certificate_configuration_url(@certificate_configuration), params: {
      certificate_configuration: {
        name: "Updated Name",
        duration_period: 10
      }
    }
    assert_redirected_to institute_admin_certificate_configurations_path
    @certificate_configuration.reload
    assert_equal "Updated Name", @certificate_configuration.name
  end

  test "should destroy certificate_configuration" do
    config_to_destroy = CertificateConfiguration.create!(
      name: "To Destroy",
      duration_period: 10,
      institute: @institute,
      status: :active
    )
    assert_difference("CertificateConfiguration.count", -1) do
      delete institute_admin_certificate_configuration_url(config_to_destroy)
    end
    assert_redirected_to institute_admin_certificate_configurations_path
  end
end
