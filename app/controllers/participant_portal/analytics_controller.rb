module ParticipantPortal
  class AnalyticsController < ParticipantPortal::BaseController
    def index
      @selected_range = params[:range].presence || "30"

      # Determine date range boundary
      start_boundary = case @selected_range
      when "7" then 7.days.ago.to_date
      when "30" then 30.days.ago.to_date
      when "90" then 90.days.ago.to_date
      else 1.year.ago.to_date
      end

      # 1. Base Participant Data Scoping (Zero N+1)
      @participant = current_participant
      base_logs = AssignmentResponseLog.where(participant: @participant)
      base_responses = AssignmentResponse.where(participant: @participant)
                                        .includes(question: :question_category)

      if @selected_range != "all"
        base_logs = base_logs.where("response_date >= ?", start_boundary)
        base_responses = base_responses.where("response_date >= ?", start_boundary)
      end

      # 2. Key Summary KPIs
      @total_questions_answered = base_responses.count
      @total_submitted_days = base_logs.pluck(:response_date).uniq.size

      # Active Submission Streak
      all_submitted_dates = AssignmentResponseLog.where(participant: @participant)
                                                .pluck(:response_date)
                                                .to_set
      @active_streak = calculate_streak(all_submitted_dates)

      # Average Self-Rating
      rating_values = base_responses.joins(:question)
                                    .where(questions: { question_type: [ "rating", "number" ] })
                                    .pluck(:answer)
                                    .filter_map { |v| Float(v) rescue nil }
      @avg_rating = rating_values.any? ? (rating_values.sum / rating_values.size.to_f).round(1) : 0.0

      # 3. Chart 1: Daily Activity Trend (Last 14-30 Days)
      days_limit = @selected_range == "7" ? 7 : 14
      date_series = (days_limit.days.ago.to_date..Date.current).to_a
      daily_counts = base_responses.where("response_date >= ?", days_limit.days.ago.to_date)
                                   .group(:response_date)
                                   .count

      @trend_labels = date_series.map { |d| d.strftime("%b %d") }
      @trend_data = date_series.map { |d| daily_counts[d] || 0 }

      # 4. Chart 2: Assignment Specific Responses Breakdown
      raw_category_counts = base_responses.joins(:assignment)
                                          .group("assignments.title")
                                          .count
      @category_labels = raw_category_counts.keys.presence || [ "No Assignments" ]
      @category_data = raw_category_counts.values.presence || [ 0 ]

      # 5. Chart 3: Question Type Distribution
      raw_type_counts = base_responses.joins(:question)
                                      .group("questions.question_type")
                                      .count
      @type_labels = raw_type_counts.keys.compact.map(&:titleize).presence || [ "No Types" ]
      @type_data = raw_type_counts.values.presence || [ 0 ]

      # 6. Detailed Assignment Performance Scorecard
      all_assignments = Assignment.for_participant(@participant).order(start_date: :desc)
      assignment_submission_counts = AssignmentResponseLog.where(participant: @participant)
                                                           .group(:assignment_id)
                                                           .count

      total_eligible_days_sum = 0
      total_submitted_days_sum = 0

      @assignment_scorecards = all_assignments.map do |assignment|
        start_d = assignment.start_date.to_date
        end_d = assignment.end_date.to_date
        total_days = (end_d - start_d).to_i + 1
        submitted_days = assignment_submission_counts[assignment.id] || 0

        total_eligible_days_sum += total_days
        total_submitted_days_sum += [ submitted_days, total_days ].min

        completion_pct = total_days > 0 ? ((submitted_days.to_f / total_days) * 100).round(1) : 0.0
        completion_pct = [ completion_pct, 100.0 ].min

        status = if completion_pct >= 100.0
                   "completed"
        elsif end_d < Date.current
                   "expired"
        else
                   "ongoing"
        end

        {
          assignment: assignment,
          total_days: total_days,
          submitted_days: submitted_days,
          completion_pct: completion_pct,
          status: status
        }
      end

      # Overall Completion Rate KPI
      @overall_completion_rate = total_eligible_days_sum > 0 ? ((total_submitted_days_sum.to_f / total_eligible_days_sum) * 100).round(1) : 0.0

      # 7. Chart 4: Day of Week Consistency (Mon - Sun)
      dow_counts = base_logs.pluck(:response_date).compact.group_by { |d| d.strftime("%a") }
      dow_order = %w[Mon Tue Wed Thu Fri Sat Sun]
      @dow_labels = dow_order
      @dow_data = dow_order.map { |day| (dow_counts[day] || []).size }

      # 8. Chart 5: Rating Trend Over Time
      rating_responses = base_responses.joins(:question)
                                       .where(questions: { question_type: [ "rating", "number" ] })
                                       .order(:response_date)
      rating_by_date = rating_responses.group_by(&:response_date)

      @rating_trend_labels = rating_by_date.keys.map { |d| d.strftime("%b %d") }
      @rating_trend_data = rating_by_date.values.map do |resps|
        vals = resps.filter_map { |r| Float(r.answer) rescue nil }
        vals.any? ? (vals.sum / vals.size.to_f).round(1) : 0.0
      end

      # 9. Top Category & Performance Highlights
      top_cat_pair = raw_category_counts.max_by { |_k, v| v }
      @top_category_name = top_cat_pair ? top_cat_pair.first : "N/A"
      @top_category_count = top_cat_pair ? top_cat_pair.last : 0
    end

    private

    def calculate_streak(submitted_dates)
      return 0 if submitted_dates.empty?

      streak = 0
      check_date = Date.current

      if submitted_dates.include?(check_date)
        while submitted_dates.include?(check_date)
          streak += 1
          check_date -= 1.day
        end
      elsif submitted_dates.include?(check_date - 1.day)
        check_date -= 1.day
        while submitted_dates.include?(check_date)
          streak += 1
          check_date -= 1.day
        end
      end

      streak
    end
  end
end
