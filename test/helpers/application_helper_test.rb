require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "format_import_log_item formats question created log" do
    log = {
      "time" => "13:09:18",
      "level" => "success",
      "message" => "Row 2: Created question 'How are you feeling today?' (Multiple Choice, Day 1-28) with 3 options."
    }

    html = format_import_log_item(log)
    assert_includes html, "timeline-step"
    assert_includes html, "timeline-node"
    assert_includes html, "timeline-content-card"
    assert_includes html, "Question Created"
    assert_includes html, "Row 2"
    assert_includes html, "How are you feeling today?"
    assert_includes html, "Multiple Choice"
    assert_includes html, "Day 1-28"
    assert_includes html, "3 options"
    assert_includes html, "13:09:18"
  end

  test "format_import_log_item formats info system log" do
    log = {
      "time" => "13:09:18",
      "level" => "info",
      "message" => "Headers validated successfully (7 total rows read)."
    }

    html = format_import_log_item(log)
    assert_includes html, "System Step"
    assert_includes html, "Headers validated successfully"
    assert_includes html, "13:09:18"
  end

  test "format_import_log_item formats error log" do
    log = {
      "time" => "13:09:18",
      "level" => "error",
      "message" => "CSV parsing failed: Malformed CSV"
    }

    html = format_import_log_item(log)
    assert_includes html, "Validation Error"
    assert_includes html, "CSV parsing failed"
  end
end
