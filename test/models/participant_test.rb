require "test_helper"

class ParticipantTest < ActiveSupport::TestCase
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
    @user = User.create!(
      email: "user_#{SecureRandom.hex(3)}@example.com",
      password: "password123",
      password_confirmation: "password123",
      role: :participant,
      first_name: "John",
      last_name: "Doe",
      institute: @institute,
      section: @section
    )
  end

  test "is valid without date_of_birth" do
    participant = Participant.new(
      user: @user,
      institute: @institute,
      section_id: @section.id,
      participant_type: :student,
      date_of_birth: nil
    )
    assert participant.valid?, "Participant should be valid without date_of_birth: #{participant.errors.full_messages}"
  end

  test "is valid with date_of_birth" do
    participant = Participant.new(
      user: @user,
      institute: @institute,
      section_id: @section.id,
      participant_type: :student,
      date_of_birth: Date.new(2005, 5, 15)
    )
    assert participant.valid?, "Participant should be valid with date_of_birth"
  end
end
