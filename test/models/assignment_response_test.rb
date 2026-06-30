require "test_helper"

class AssignmentResponseTest < ActiveSupport::TestCase
  setup do
    @assignment = assignments(:one)
    @participant = participants(:one)
    @required_question = questions(:required_question)
    @optional_question = questions(:optional_question)
  end

  test "validates presence of answer for required questions" do
    response = AssignmentResponse.new(
      assignment: @assignment,
      participant: @participant,
      question: @required_question,
      response_date: Date.today,
      answer: ""
    )
    assert_not response.valid?
    assert_includes response.errors[:answer], "must be present"

    response.answer = "Some answer"
    assert response.valid?
  end

  test "does not validate presence of answer for optional questions" do
    response = AssignmentResponse.new(
      assignment: @assignment,
      participant: @participant,
      question: @optional_question,
      response_date: Date.today,
      answer: ""
    )
    assert response.valid?
  end
end
