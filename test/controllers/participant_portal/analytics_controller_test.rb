require "test_helper"

module ParticipantPortal
  class AnalyticsControllerTest < ActionDispatch::IntegrationTest
    include Devise::Test::IntegrationHelpers

    setup do
      @user = users(:two) # participant user fixture
      @participant = participants(:two)
      sign_in @user
    end

    test "should get index" do
      get participant_portal_analytics_url
      assert_response :success
      assert_select "h3", text: /Performance Analytics/
    end

    test "should filter by date range" do
      get participant_portal_analytics_url(range: "7")
      assert_response :success

      get participant_portal_analytics_url(range: "all")
      assert_response :success
    end
  end
end
