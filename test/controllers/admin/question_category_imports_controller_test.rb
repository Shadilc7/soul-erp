require "test_helper"

class Admin::QuestionCategoryImportsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @admin = users(:master_admin)
    sign_in @admin
    @bank = QuestionBank.create!(name: "Test Bank")
    @category = QuestionCategory.create!(
      question_bank: @bank,
      name: "Wellness Category",
      duration_days: 30
    )
  end

  test "should get new" do
    get new_admin_question_category_import_path(@category)
    assert_response :success
    assert_select "h2", text: /Import Questions into Wellness Category/
    assert_select "a[data-turbo='false'][href*='sample_excel_template']"
    assert_select "a[data-turbo='false'][href*='sample_template']"
    assert_select "a[data-turbo='false'][href*='blank_excel_template']"
    assert_select "a[data-turbo='false'][href*='blank_template']"
  end

  test "should get index" do
    @category.question_imports.create!(filename: "past.csv", status: :completed)
    get admin_question_category_imports_path(@category)
    assert_response :success
    assert_select "h2", text: /Import History/
  end

  test "should download sample_template" do
    get sample_template_admin_question_category_imports_path(@category)
    assert_response :success
    assert_equal "text/csv; charset=utf-8", response.content_type
    assert_includes response.body, "Question Title / Statement"
    assert_includes response.body, "multiple_choice"
  end

  test "should download sample_excel_template" do
    get sample_excel_template_admin_question_category_imports_path(@category)
    assert_response :success
    assert_equal "application/vnd.ms-excel; charset=utf-8", response.content_type
    assert_includes response.body, "Question Title / Statement"
    assert_includes response.body, "urn:schemas-microsoft-com:office:spreadsheet"
  end

  test "should download blank_template with exact headers only" do
    get blank_template_admin_question_category_imports_path(@category)
    assert_response :success
    assert_equal "text/csv; charset=utf-8", response.content_type
    content = response.body.sub(/\A\xEF\xBB\xBF/, "").strip
    lines = content.split("\n")
    assert_equal 1, lines.size
    assert_includes lines.first, "Question Title / Statement"
    refute_includes response.body, "Accept only numbers"
  end

  test "should download blank_excel_template with exact headers only" do
    get blank_excel_template_admin_question_category_imports_path(@category)
    assert_response :success
    assert_equal "application/vnd.ms-excel; charset=utf-8", response.content_type
    assert_includes response.body, "Question Title / Statement"
    assert_includes response.body, "urn:schemas-microsoft-com:office:spreadsheet"
    refute_includes response.body, "e.g. How are you feeling today?"
    refute_includes response.body, "What was the main accomplishment of your day?"
  end

  test "should create import and redirect to show" do
    csv_file = Rack::Test::UploadedFile.new(
      StringIO.new("Question Title / Statement,Question Type\nTest Question,short_answer\n"),
      "text/csv",
      original_filename: "test.csv"
    )

    assert_difference "@category.question_imports.count", 1 do
      post admin_question_category_imports_path(@category), params: {
        file: csv_file,
        question_import: {
          auto_assign_bundles: "1",
          dry_run: "0"
        }
      }
    end

    import = @category.question_imports.last
    assert_redirected_to admin_question_category_import_path(@category, import)
  end

  test "should create import when question_import param is absent" do
    csv_file = Rack::Test::UploadedFile.new(
      StringIO.new("Question Title / Statement,Question Type\nTest Question,short_answer\n"),
      "text/csv",
      original_filename: "test.csv"
    )

    assert_difference "@category.question_imports.count", 1 do
      post admin_question_category_imports_path(@category), params: {
        file: csv_file
      }
    end

    import = @category.question_imports.last
    assert_redirected_to admin_question_category_import_path(@category, import)
  end

  test "should get show and status json" do
    import = @category.question_imports.create!(
      filename: "test.csv",
      status: :completed,
      total_rows: 5,
      successful_rows: 5,
      failed_rows: 0,
      process_log: [{ "time" => "12:00:00", "level" => "info", "message" => "Finished" }]
    )

    get admin_question_category_import_path(@category, import)
    assert_response :success
    assert_select "h2", text: /Import Details & Execution Log/

    get status_admin_question_category_import_path(@category, import)
    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "completed", json["status"]
    assert_equal 5, json["total_rows"]
    assert_equal 5, json["successful_rows"]
  end

  test "should download failed_rows CSV" do
    import = @category.question_imports.create!(
      filename: "test.csv",
      status: :partially_completed,
      total_rows: 2,
      successful_rows: 1,
      failed_rows: 1,
      error_log: [{
        "row" => 2,
        "title" => "Bad Day Range",
        "errors" => ["To Day cannot exceed 30"],
        "raw_data" => { "Question Title / Statement" => "Bad Day Range" }
      }]
    )

    get failed_rows_admin_question_category_import_path(@category, import)
    assert_response :success
    assert_equal "text/csv; charset=utf-8", response.content_type
    assert_includes response.body, "Bad Day Range"
    assert_includes response.body, "To Day cannot exceed 30"
  end
end
