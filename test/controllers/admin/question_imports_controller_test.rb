require "test_helper"

class Admin::QuestionImportsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @admin = users(:master_admin)
    sign_in @admin
    @bank = QuestionBank.create!(name: "Test Bank")
    @category1 = QuestionCategory.create!(question_bank: @bank, name: "Category 1", duration_days: 30)
    @category2 = QuestionCategory.create!(question_bank: @bank, name: "Category 2", duration_days: 15)

    @import1 = @category1.question_imports.create!(filename: "file1.csv", status: :completed, total_rows: 5, successful_rows: 5)
    @import2 = @category2.question_imports.create!(filename: "file2.csv", status: :failed, total_rows: 3, failed_rows: 3)
  end

  test "should get index with all import logs" do
    get admin_question_imports_path
    assert_response :success
    assert_select "h2", text: /Question Import Logs/
    assert_select "td", text: /Category 1/
    assert_select "td", text: /Category 2/
  end

  test "should filter index by category" do
    get admin_question_imports_path, params: { question_category_id: @category1.id }
    assert_response :success
    assert_select "td", text: /Category 1/
    assert_select "td", text: /Category 2/, count: 0
  end

  test "should filter index by status" do
    get admin_question_imports_path, params: { status: "failed" }
    assert_response :success
    assert_select "td", text: /Category 2/
    assert_select "td", text: /Category 1/, count: 0
  end

  test "should display question bank name in table" do
    get admin_question_imports_path
    assert_response :success
    assert_select "td", text: /Test Bank/
  end

  test "should filter index by question bank" do
    bank2 = QuestionBank.create!(name: "Second Bank")
    category3 = QuestionCategory.create!(question_bank: bank2, name: "Category 3", duration_days: 20)
    import3 = category3.question_imports.create!(filename: "file3.csv", status: :completed, total_rows: 2, successful_rows: 2)

    get admin_question_imports_path, params: { question_bank_id: @bank.id }
    assert_response :success
    assert_select "td", text: /Category 1/
    assert_select "td", text: /Category 2/
    assert_select "td", text: /Category 3/, count: 0
  end

  test "should redirect show to category import show" do
    get admin_question_import_path(@import1)
    assert_redirected_to admin_question_category_import_path(@category1, @import1)
  end

  test "should display live imports and dry runs in separate sections" do
    dry_import = @category1.question_imports.create!(
      filename: "dry_test.csv",
      status: :completed,
      total_rows: 4,
      successful_rows: 4,
      dry_run: true
    )

    get admin_question_imports_path
    assert_response :success
    assert_select "h5", text: /Live Question Imports/
    assert_select "h5", text: /Dry Run Validations & Simulations/
    assert_select "th", text: /Serial Number/
    assert_select "td[title='Import ID ##{@import2.id}']", text: /#1/
    assert_select "td[title='Import ID ##{@import1.id}']", text: /#2/
    assert_select "td[title='Import ID ##{dry_import.id}']", text: /#1/
  end

  test "should filter to live imports only when mode is live" do
    dry_import = @category1.question_imports.create!(
      filename: "dry_test.csv",
      status: :completed,
      total_rows: 4,
      successful_rows: 4,
      dry_run: true
    )

    get admin_question_imports_path, params: { mode: "live" }
    assert_response :success
    assert_select "h5", text: /Live Question Imports/
    assert_select "h5", text: /Dry Run Validations & Simulations/, count: 0
    assert_select "td[title='Import ID ##{@import1.id}']"
    assert_select "td[title='Import ID ##{dry_import.id}']", count: 0
  end

  test "should filter to dry runs only when mode is dry_run" do
    dry_import = @category1.question_imports.create!(
      filename: "dry_test.csv",
      status: :completed,
      total_rows: 4,
      successful_rows: 4,
      dry_run: true
    )

    get admin_question_imports_path, params: { mode: "dry_run" }
    assert_response :success
    assert_select "h5", text: /Live Question Imports/, count: 0
    assert_select "h5", text: /Dry Run Validations & Simulations/
    assert_select "td[title='Import ID ##{@import1.id}']", count: 0
    assert_select "td[title='Import ID ##{dry_import.id}']"
  end
end
