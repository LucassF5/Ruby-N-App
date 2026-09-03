class CalendarController < ApplicationController
  def show
    @month = month_param
    @weeks = weeks_of_month(@month)
    @colors_by_day = colors_by_day(@month)
  end

  private

  def month_param
    Date.strptime(params[:month], "%Y-%m").beginning_of_month
  rescue ArgumentError, TypeError
    Date.current.beginning_of_month
  end

  def weeks_of_month(month)
    first = month.beginning_of_month.beginning_of_week(:sunday)
    last = month.end_of_month.end_of_week(:sunday)
    (first..last).to_a.each_slice(7).to_a
  end

  def colors_by_day(month)
    Shift.where(date: month.beginning_of_month..month.end_of_month)
         .includes(:category)
         .group_by(&:date)
         .transform_values { |shifts| shifts.map { |s| s.category&.color || "#94a3b8" }.uniq }
  end
end
