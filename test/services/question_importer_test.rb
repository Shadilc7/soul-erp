require "test_helper"

class QuestionImporterTest < ActiveSupport::TestCase
  setup do
    @category = QuestionCategory.create!(name: "Health & Wellness", duration_days: 30)
  end

  def attach_csv(import, csv_content)
    import.file.attach(
      io: StringIO.new(csv_content),
      filename: "test_questions.csv",
      content_type: "text/csv"
    )
  end

  test "imports valid questions and skips guidance row" do
    csv = <<~CSV
      Question Title / Statement,Display Name (Optional),From Day,To Day,Description / Instructions (Optional),Question Type,Required Question,Active Question,Options (Optional, pipe separated),Max Rating (Optional)
      ,,Accept only numbers,Accept only numbers,,"Checkboxes,short answer,etc",,,,
      How are you feeling today?,Mood,1,30,Brief checkin,short_answer,Yes,Yes,,
      What is your preferred routine?,Routine,1,15,,multiple_choice,No,Yes,Morning | Evening | Both,
      Rate your energy,Energy,1,30,,rating,Yes,Yes,,5
      Did you walk outside?,Walk,1,30,,yes_or_no,No,Yes,,
    CSV

    import = QuestionImport.create!(question_category: @category)
    attach_csv(import, csv)

    assert_difference "Question.count", 4 do
      assert QuestionImporter.new(import).process!
    end

    import.reload
    assert_equal "completed", import.status
    assert_equal 4, import.total_rows
    assert_equal 4, import.successful_rows
    assert_equal 0, import.failed_rows
    assert_empty import.error_log

    # Verify options for multiple choice
    mc_q = Question.find_by(title: "What is your preferred routine?")
    assert_not_nil mc_q
    assert_equal 3, mc_q.options.count
    assert_equal ["Morning", "Evening", "Both"], mc_q.options.pluck(:text)

    # Verify options for yes_or_no auto-created
    yn_q = Question.find_by(title: "Did you walk outside?")
    assert_not_nil yn_q
    assert_equal ["Yes", "No"], yn_q.options.pluck(:text)
  end

  test "rejects row where to_day exceeds category duration_days" do
    csv = <<~CSV
      Question Title / Statement,Display Name (Optional),From Day,To Day,Description / Instructions (Optional),Question Type,Required Question,Active Question
      Valid Question,,1,20,,short_answer,Yes,Yes
      Invalid Question,,1,45,,short_answer,Yes,Yes
    CSV

    import = QuestionImport.create!(question_category: @category)
    attach_csv(import, csv)

    assert_difference "Question.count", 1 do
      QuestionImporter.new(import).process!
    end

    import.reload
    assert_equal "partially_completed", import.status
    assert_equal 2, import.total_rows
    assert_equal 1, import.successful_rows
    assert_equal 1, import.failed_rows

    assert_equal 1, import.error_log.size
    err = import.error_log.first
    assert_equal "Invalid Question", err["title"]
    assert_includes err["errors"].join, "cannot exceed category maximum duration of 30 days"
  end

  test "rejects choice questions with fewer than 2 options" do
    csv = <<~CSV
      Question Title / Statement,Display Name (Optional),From Day,To Day,Description / Instructions (Optional),Question Type,Required Question,Active Question,Options (Optional, pipe separated)
      Broken Choice,,1,30,,multiple_choice,Yes,Yes,Only One Option
    CSV

    import = QuestionImport.create!(question_category: @category)
    attach_csv(import, csv)

    assert_no_difference "Question.count" do
      QuestionImporter.new(import).process!
    end

    import.reload
    assert_equal "failed", import.status
    assert_equal 1, import.failed_rows
    assert_includes import.error_log.first["errors"].join, "require at least 2 options"
  end

  test "imports questions directly into category pool without modifying bundles" do
    bundle = @category.question_bundles.create!(name: "Phase 1 Basics", from_day: 1, to_day: 10)

    csv = <<~CSV
      Question Title / Statement,Display Name (Optional),From Day,To Day,Description / Instructions (Optional),Question Type,Required Question,Active Question
      Phase 1 Question,,1,10,,short_answer,Yes,Yes
      Phase 2 Question,,15,30,,short_answer,Yes,Yes
    CSV

    import = QuestionImport.create!(question_category: @category)
    attach_csv(import, csv)

    QuestionImporter.new(import).process!

    q1 = Question.find_by(title: "Phase 1 Question")
    q2 = Question.find_by(title: "Phase 2 Question")

    assert_not_nil q1
    assert_not_nil q2
    assert_equal @category.id, q1.question_category_id
    assert_equal @category.id, q2.question_category_id
    assert_empty bundle.questions
  end

  test "dry run validates without creating database records" do
    csv = <<~CSV
      Question Title / Statement,Display Name (Optional),From Day,To Day,Description / Instructions (Optional),Question Type,Required Question,Active Question
      Dry Run Question,,1,10,,short_answer,Yes,Yes
    CSV

    import = QuestionImport.create!(question_category: @category, dry_run: true)
    attach_csv(import, csv)

    assert_no_difference "Question.count" do
      QuestionImporter.new(import).process!
    end

    import.reload
    assert_equal "completed", import.status
    assert_equal 1, import.total_rows
    assert_equal 0, import.failed_rows
    assert_empty import.imported_question_ids
  end

  test "rollback on error mode reverts all changes when a row fails" do
    csv = <<~CSV
      Question Title / Statement,Display Name (Optional),From Day,To Day,Description / Instructions (Optional),Question Type,Required Question,Active Question
      Good Question,,1,10,,short_answer,Yes,Yes
      Bad Question,,1,999,,short_answer,Yes,Yes
    CSV

    import = QuestionImport.create!(question_category: @category, rollback_on_error: true)
    attach_csv(import, csv)

    assert_no_difference "Question.count" do
      QuestionImporter.new(import).process!
    end

    import.reload
    assert_equal "failed", import.status
    assert_equal 0, import.successful_rows
    assert_equal 1, import.failed_rows
  end

  test "imports questions from Excel SpreadsheetML (.xls) template" do
    xml = <<~XML
      <?xml version="1.0"?>
      <?mso-application progid="Excel.Sheet"?>
      <Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet" xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet">
        <Worksheet ss:Name="Questions">
          <Table>
            <Row ss:Height="26">
              <Cell><Data ss:Type="String">Question Title / Statement</Data></Cell>
              <Cell><Data ss:Type="String">Display Name (Optional)</Data></Cell>
              <Cell><Data ss:Type="String">From Day</Data></Cell>
              <Cell><Data ss:Type="String">To Day</Data></Cell>
              <Cell><Data ss:Type="String">Description / Instructions (Optional)</Data></Cell>
              <Cell><Data ss:Type="String">Question Type</Data></Cell>
              <Cell><Data ss:Type="String">Required Question</Data></Cell>
              <Cell><Data ss:Type="String">Active Question</Data></Cell>
              <Cell><Data ss:Type="String">Options (Optional, pipe separated)</Data></Cell>
              <Cell><Data ss:Type="String">Max Rating (Optional)</Data></Cell>
            </Row>
            <Row>
              <Cell><Data ss:Type="String">e.g. How are you feeling today?</Data></Cell>
              <Cell><Data ss:Type="String">Daily Mood</Data></Cell>
              <Cell><Data ss:Type="String">1</Data></Cell>
              <Cell><Data ss:Type="String">30</Data></Cell>
              <Cell><Data ss:Type="String">Instructions</Data></Cell>
              <Cell><Data ss:Type="String">multiple_choice</Data></Cell>
              <Cell><Data ss:Type="String">Yes</Data></Cell>
              <Cell><Data ss:Type="String">Yes</Data></Cell>
              <Cell><Data ss:Type="String">Option A | Option B</Data></Cell>
              <Cell><Data ss:Type="String">5</Data></Cell>
            </Row>
            <Row>
              <Cell><Data ss:Type="String">Excel Question One</Data></Cell>
              <Cell><Data ss:Type="String">Ex Q1</Data></Cell>
              <Cell><Data ss:Type="String">1</Data></Cell>
              <Cell><Data ss:Type="String">15</Data></Cell>
              <Cell><Data ss:Type="String">Note</Data></Cell>
              <Cell><Data ss:Type="String">short_answer</Data></Cell>
              <Cell><Data ss:Type="String">Yes</Data></Cell>
              <Cell><Data ss:Type="String">Yes</Data></Cell>
              <Cell><Data ss:Type="String"></Data></Cell>
              <Cell><Data ss:Type="String"></Data></Cell>
            </Row>
            <Row>
              <Cell><Data ss:Type="String">Excel Question Two</Data></Cell>
              <Cell><Data ss:Type="String">Ex Q2</Data></Cell>
              <Cell><Data ss:Type="String">1</Data></Cell>
              <Cell><Data ss:Type="String">30</Data></Cell>
              <Cell><Data ss:Type="String"></Data></Cell>
              <Cell><Data ss:Type="String">multiple_choice</Data></Cell>
              <Cell><Data ss:Type="String">No</Data></Cell>
              <Cell><Data ss:Type="String">Yes</Data></Cell>
              <Cell><Data ss:Type="String">Red | Green | Blue</Data></Cell>
              <Cell><Data ss:Type="String"></Data></Cell>
            </Row>
          </Table>
        </Worksheet>
      </Workbook>
    XML

    import = QuestionImport.create!(question_category: @category)
    import.file.attach(
      io: StringIO.new(xml),
      filename: "question_import_sample_template_health.xls",
      content_type: "application/vnd.ms-excel"
    )

    assert_difference "Question.count", 2 do
      assert QuestionImporter.new(import).process!
    end

    import.reload
    assert_equal "completed", import.status
    assert_equal 2, import.total_rows
    assert_equal 2, import.successful_rows
    assert_equal 0, import.failed_rows

    q1 = Question.find_by(title: "Excel Question One")
    assert_not_nil q1
    assert_equal "short_answer", q1.question_type
    assert_equal "Ex Q1", q1.display_name

    q2 = Question.find_by(title: "Excel Question Two")
    assert_not_nil q2
    assert_equal 3, q2.options.count
    assert_equal ["Red", "Green", "Blue"], q2.options.pluck(:text)
  end
end
