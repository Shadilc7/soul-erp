require "test_helper"

class QuestionBankTest < ActiveSupport::TestCase
  setup do
    @institute = Institute.first || Institute.create!(
      name: "Test Institute",
      code: "INST_QB",
      email: "inst_qb@example.com",
      contact_number: "9876543210",
      institution_type: "college"
    )
  end

  test "should be valid with name" do
    bank = QuestionBank.new(name: "Engineering Bank", description: "All engineering categories")
    assert bank.valid?
  end

  test "should require name" do
    bank = QuestionBank.new(description: "No name")
    assert_not bank.valid?
    assert_includes bank.errors[:name], "can't be blank"
  end

  test "calculates total_categories_count and total_questions_count correctly" do
    bank = QuestionBank.create!(name: "Science Bank")
    cat1 = QuestionCategory.create!(name: "Physics", duration_days: 30, question_bank: bank, institute: nil)
    cat2 = QuestionCategory.create!(name: "Chemistry", duration_days: 30, question_bank: bank, institute: nil)
    cat1.questions.create!(title: "Q1", question_type: "short_answer", institute: nil)
    cat1.questions.create!(title: "Q2", question_type: "short_answer", institute: nil)
    cat2.questions.create!(title: "Q3", question_type: "short_answer", institute: nil)

    assert_equal 2, bank.total_categories_count
    assert_equal 3, bank.total_questions_count
  end

  test "allows destroy when no categories or questions are in assignments" do
    bank = QuestionBank.create!(name: "Unused Bank")
    cat = QuestionCategory.create!(name: "Unused Cat", duration_days: 15, question_bank: bank, institute: nil)
    cat.questions.create!(title: "Unused Q", question_type: "short_answer", institute: nil)

    assert_difference "QuestionBank.count", -1 do
      assert_difference "QuestionCategory.count", -1 do
        assert_difference "Question.count", -1 do
          assert bank.destroy
        end
      end
    end
  end

  test "blocks destroy when category is used in assignments" do
    bank = QuestionBank.create!(name: "Used Bank")
    cat = QuestionCategory.create!(name: "Assigned Cat", duration_days: 20, question_bank: bank, institute: nil)
    Assignment.create!(
      title: "Test Assignment",
      institute: @institute,
      question_category: cat,
      start_date: Date.today,
      end_date: Date.today + 5.days,
      assignment_type: "individual"
    )

    assert_no_difference "QuestionBank.count" do
      refute bank.destroy
    end
    assert_includes bank.errors[:base].join, "Cannot delete Question Bank 'Used Bank' because category 'Assigned Cat' is being used in assignments."
  end

  test "blocks destroy when questions in a category are used in assignments" do
    bank = QuestionBank.create!(name: "Used Bank Questions")
    cat = QuestionCategory.create!(name: "Cat with Assigned Question", duration_days: 20, question_bank: bank, institute: nil)
    q = cat.questions.create!(title: "Assigned Question", question_type: "short_answer", institute: nil)
    assignment = Assignment.create!(
      title: "Test Assignment For Question",
      institute: @institute,
      start_date: Date.today,
      end_date: Date.today + 5.days,
      assignment_type: "individual"
    )
    assignment.assignment_questions.create!(question: q, order_number: 1)

    assert_no_difference "QuestionBank.count" do
      refute bank.destroy
    end
    assert_includes bank.errors[:base].join, "Cannot delete Question Bank 'Used Bank Questions' because category 'Cat with Assigned Question' is being used in assignments."
  end
end
