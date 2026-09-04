class CalendarMonth
  attr_reader :month, :weeks, :colors_by_day

  def initialize(user, month: nil, date: nil)
    @month = resolve_month(month, date)
    @weeks = compute_weeks(@month)
    @colors_by_day = compute_colors_by_day(user, @weeks)
  end

  private
    def resolve_month(month_string, date)
      if month_string.present?
        Date.strptime(month_string, "%Y-%m").beginning_of_month
      elsif date
        date.beginning_of_month
      else
        Date.current.beginning_of_month
      end
    rescue ArgumentError, TypeError
      Date.current.beginning_of_month
    end

    def compute_weeks(month)
      first = month.beginning_of_month.beginning_of_week(:sunday)
      last = month.end_of_month.end_of_week(:sunday)
      (first..last).to_a.each_slice(7).to_a
    end

    def compute_colors_by_day(user, weeks)
      user.shifts.where(date: weeks.first.first..weeks.last.last)
          .includes(:category)
          .group_by(&:date)
          .transform_values do |shifts|
            shifts.uniq { |s| s.category_id }.map { |s| s.category&.color || "#94a3b8" }
          end
    end
end
