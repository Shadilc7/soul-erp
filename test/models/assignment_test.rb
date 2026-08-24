require "test_helper"

class AssignmentTest < ActiveSupport::TestCase
  setup do
    @institute = Institute.create!(
      name: "Test Institute",
      code: "INST#{SecureRandom.hex(3)}",
      email: "inst_#{SecureRandom.hex(3)}@example.com",
      contact_number: "9876543210",
      institution_type: "School"
    )
    @bank = QuestionBank.create!(name: "Test Bank")
    @category = QuestionCategory.create!(name: "Test Category", question_bank: @bank, duration_days: 30)

    @bundle1 = QuestionBundle.create!(question_category: @category, name: "Part1", position: 1, from_day: 1, to_day: 10)
    @bundle2 = QuestionBundle.create!(question_category: @category, name: "Part2", position: 2, from_day: 11, to_day: 25)

    @q1_b1 = Question.create!(title: "Q1 B1 5 Days", question_type: "short_answer", from_day: 1, to_day: 5, institute: @institute)
    @q2_b1 = Question.create!(title: "Q2 B1 10 Days", question_type: "short_answer", from_day: 1, to_day: 10, institute: @institute)
    @q3_b1 = Question.create!(title: "Q3 B1 All Days", question_type: "short_answer", from_day: 1, to_day: 10, institute: @institute)

    @q1_b2 = Question.create!(title: "Q1 B2 10 Days", question_type: "short_answer", from_day: 11, to_day: 20, institute: @institute)
    @q2_b2 = Question.create!(title: "Q2 B2 15 Days", question_type: "short_answer", from_day: 11, to_day: 25, institute: @institute)
    @q3_b2 = Question.create!(title: "Q3 B2 All Days", question_type: "short_answer", from_day: 11, to_day: 25, institute: @institute)

    @assignment = Assignment.create!(
      title: "Sequential Assignment",
      start_date: Date.new(2026, 8, 1),
      end_date: Date.new(2026, 8, 31),
      assignment_type: "individual",
      institute: @institute,
      question_category: @category,
      skip_association_validation: true
    )

    # Assign questions to Part1 and Part2
    AssignmentQuestion.create!(assignment: @assignment, question: @q1_b1, bundle_name: "Part1", order_number: 1)
    AssignmentQuestion.create!(assignment: @assignment, question: @q2_b1, bundle_name: "Part1", order_number: 2)
    AssignmentQuestion.create!(assignment: @assignment, question: @q3_b1, bundle_name: "Part1", order_number: 3)

    AssignmentQuestion.create!(assignment: @assignment, question: @q1_b2, bundle_name: "Part2", order_number: 4)
    AssignmentQuestion.create!(assignment: @assignment, question: @q2_b2, bundle_name: "Part2", order_number: 5)
    AssignmentQuestion.create!(assignment: @assignment, question: @q3_b2, bundle_name: "Part2", order_number: 6)
  end

  test "returns correct questions for Day 3 (Aug 3) in Bundle 1" do
    grouped = @assignment.questions_grouped_by_bundle_for_date(Date.new(2026, 8, 3))
    assert_includes grouped.keys, "Part1"
    refute_includes grouped.keys, "Part2"

    part1_questions = grouped["Part1"]
    assert_equal 3, part1_questions.size
    assert_equal [@q1_b1.id, @q2_b1.id, @q3_b1.id], part1_questions.map(&:id)
  end

  test "returns correct questions for Day 6 (Aug 6) in Bundle 1 after 5-day question expires" do
    grouped = @assignment.questions_grouped_by_bundle_for_date(Date.new(2026, 8, 6))
    assert_includes grouped.keys, "Part1"
    refute_includes grouped.keys, "Part2"

    part1_questions = grouped["Part1"]
    assert_equal 2, part1_questions.size
    assert_equal [@q2_b1.id, @q3_b1.id], part1_questions.map(&:id)
  end

  test "returns correct questions for Day 12 (Aug 12) in Bundle 2" do
    # Bundle 1 runs Aug 1 to Aug 10 (10 days). Bundle 2 runs Aug 11 to Aug 25 (15 days).
    grouped = @assignment.questions_grouped_by_bundle_for_date(Date.new(2026, 8, 12))
    refute_includes grouped.keys, "Part1"
    assert_includes grouped.keys, "Part2"

    part2_questions = grouped["Part2"]
    assert_equal 3, part2_questions.size
    assert_equal [@q1_b2.id, @q2_b2.id, @q3_b2.id], part2_questions.map(&:id)
  end

  test "returns correct questions for Day 22 (Aug 22) in Bundle 2 after 10-day question expires" do
    # Bundle 2 starts Aug 11. Q1 B2 (10 days) runs Aug 11 to Aug 20. On Aug 22, it is expired.
    grouped = @assignment.questions_grouped_by_bundle_for_date(Date.new(2026, 8, 22))
    refute_includes grouped.keys, "Part1"
    assert_includes grouped.keys, "Part2"

    part2_questions = grouped["Part2"]
    assert_equal 2, part2_questions.size
    assert_equal [@q2_b2.id, @q3_b2.id], part2_questions.map(&:id)
  end

  test "returns latest unanswered date for a participant" do
    user = User.create!(
      email: "part_#{SecureRandom.hex(3)}@example.com",
      password: "password123",
      first_name: "John",
      last_name: "Doe",
      role: "participant",
      institute: @institute
    )
    section = Section.create!(name: "Test Section", code: "SEC1", capacity: 30, institute: @institute)
    participant = Participant.create!(
      user: user,
      institute: @institute,
      date_of_birth: Date.new(2000, 1, 1),
      section_id: section.id
    )
    AssignmentParticipant.create!(assignment: @assignment, participant: participant)
    # Freeze time at Aug 3, 2026
    travel_to Date.new(2026, 8, 3) do
      assert_equal Date.new(2026, 8, 3), @assignment.latest_unanswered_date_for(participant)
    end
  end

  test "cannot destroy assignment when individual certificates exist and adds error" do
    section = Section.create!(name: "Cert Section", code: "CSEC#{SecureRandom.hex(2)}", capacity: 30, institute: @institute)
    user = User.create!(
      email: "cert_user_#{SecureRandom.hex(3)}@example.com",
      password: "password123",
      first_name: "Cert",
      last_name: "Participant",
      role: "participant",
      institute: @institute,
      section_id: section.id
    )
    participant = Participant.create!(
      user: user,
      institute: @institute,
      date_of_birth: Date.new(2000, 1, 1),
      section_id: section.id
    )
    config = CertificateConfiguration.create!(
      institute: @institute,
      name: "Completion Cert",
      duration_period: 10
    )
    IndividualCertificate.create!(
      institute: @institute,
      participant: participant,
      assignment: @assignment,
      certificate_configuration: config,
      generated_at: Time.current
    )

    assert_no_difference("Assignment.count") do
      refute @assignment.destroy
    end

    assert @assignment.errors[:base].present?
    assert_includes @assignment.errors[:base].first, "Cannot delete assignment"
    assert_includes @assignment.errors[:base].first, "certificate"
  end

  test "can destroy assignment when no individual certificates exist" do
    assignment_to_delete = Assignment.create!(
      title: "Clean Assignment",
      start_date: Date.new(2026, 8, 1),
      end_date: Date.new(2026, 8, 31),
      assignment_type: "individual",
      institute: @institute,
      skip_association_validation: true
    )

    assert_difference("Assignment.count", -1) do
      assert assignment_to_delete.destroy
    end
  end
end
