require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @institute = Institute.create!(
      name: "Test Institute",
      code: "INST#{SecureRandom.hex(3)}",
      email: "inst_#{SecureRandom.hex(3)}@example.com",
      contact_number: "9876543210",
      institution_type: "School"
    )
    @section = Section.create!(
      name: "Section A",
      code: "SEC-A-#{SecureRandom.hex(2)}",
      capacity: 30,
      institute: @institute
    )
    setting = RegistrationSetting.instance
    setting.update!(enabled_institutes: (setting.enabled_institute_ids + [@institute.id]).uniq)
  end

  test "should register participant successfully without date_of_birth" do
    assert_difference("User.count", 1) do
      assert_difference("Participant.count", 1) do
        post user_registration_path, params: {
          user: {
            first_name: "Jane",
            last_name: "Doe",
            email: "jane_doe_#{SecureRandom.hex(3)}@example.com",
            password: "password123",
            password_confirmation: "password123",
            participant_attributes: {
              institute_id: @institute.id,
              section_id: @section.id,
              participant_type: "student",
              phone_number: "9876543210",
              date_of_birth: ""
            }
          }
        }
      end
    end

    assert_redirected_to new_user_session_path
    follow_redirect!
    assert_match "Registration successful! Your account is pending for approval.", response.body

    participant = User.order(:created_at).last.participant
    assert_nil participant.date_of_birth
  end

  test "should register participant successfully with date_of_birth" do
    dob = "2006-08-12"
    assert_difference("User.count", 1) do
      assert_difference("Participant.count", 1) do
        post user_registration_path, params: {
          user: {
            first_name: "Alex",
            last_name: "Smith",
            email: "alex_smith_#{SecureRandom.hex(3)}@example.com",
            password: "password123",
            password_confirmation: "password123",
            participant_attributes: {
              institute_id: @institute.id,
              section_id: @section.id,
              participant_type: "student",
              phone_number: "9876543211",
              date_of_birth: dob
            }
          }
        }
      end
    end

    assert_redirected_to new_user_session_path
    participant = User.order(:created_at).last.participant
    assert_equal Date.parse(dob), participant.date_of_birth
  end

  test "registration form does not have required attribute on date_of_birth field" do
    get new_user_registration_path
    assert_response :success
    assert_select "input[name='user[participant_attributes][date_of_birth]']" do |elements|
      assert_equal 1, elements.size
      assert_nil elements.first["required"], "date_of_birth input should not be required"
    end
  end
end
