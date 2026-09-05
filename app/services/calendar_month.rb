class CalendarMonth
  attr_reader :month, :weeks, :colors_by_day

  def initialize(user, month: nil, date: nil)
    @user = user
    @month = resolve_month(month, date)
    @weeks = compute_weeks(@month)
    @colors_by_day = compute_colors_by_day(@user, @weeks)
    @shifts = compute_shifts(@user, @month)
  end

  def shifts_count
    @shifts.size
  end

  def total_hours
    @shifts.sum { |shift| shift_duration_in_hours(shift) }
  end

  def category_breakdown
    @shifts.group_by(&:category)
           .map { |category, shifts| { name: category&.name || "Sem categoria", color: category&.color || "#94a3b8", count: shifts.size } }
           .sort_by { |entry| -entry[:count] }
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
      Shift.category_colors_by_date(user, weeks.first.first..weeks.last.last)
    end

    def compute_shifts(user, month)
      user.shifts.where(date: month.beginning_of_month..month.end_of_month).includes(:category)
    end

    # end_time <= start_time means the shift crosses midnight into the next day.
    def shift_duration_in_hours(shift)
      duration = shift.end_time - shift.start_time
      duration += 24.hours if duration <= 0
      duration / 1.hour
    end
end
