require "test_helper"

class QuestionImportTest < ActiveSupport::TestCase
  setup do
    @category = QuestionCategory.create!(name: "Test Category", duration_days: 30)
  end

  test "should be valid with question_category" do
    import = QuestionImport.new(question_category: @category)
    assert import.valid?
    assert_equal "pending", import.status
  end

  test "should require question_category" do
    import = QuestionImport.new(question_category: nil)
    assert_not import.valid?
    assert_includes import.errors[:question_category], "must exist"
  end

  test "calculates success_rate correctly" do
    import = QuestionImport.new(
      question_category: @category,
      total_rows: 10,
      successful_rows: 7,
      failed_rows: 3
    )
    assert_equal 70, import.success_rate

    import.total_rows = 0
    assert_equal 0, import.success_rate
  end

  test "has_errors? returns true when failed_rows or error_log is present" do
    import = QuestionImport.new(question_category: @category, failed_rows: 0, error_log: [])
    assert_not import.has_errors?

    import.failed_rows = 2
    assert import.has_errors?

    import.failed_rows = 0
    import.error_log = [{ "row" => 2, "errors" => ["Title missing"] }]
    assert import.has_errors?
  end

  test "completed_or_failed? detects terminal statuses" do
    import = QuestionImport.new(question_category: @category, status: :pending)
    assert_not import.completed_or_failed?

    import.status = :processing
    assert_not import.completed_or_failed?

    import.status = :completed
    assert import.completed_or_failed?

    import.status = :failed
    assert import.completed_or_failed?

    import.status = :partially_completed
    assert import.completed_or_failed?
  end
end
