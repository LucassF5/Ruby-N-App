class CalendarController < ApplicationController
  def show
    calendar = CalendarMonth.new(Current.user, month: params[:month])
    @month = calendar.month
    @weeks = calendar.weeks
    @colors_by_day = calendar.colors_by_day
  end

  def day
    @date = Date.parse(params[:date])
    @shifts = Current.user.shifts.where(date: @date).includes(:category).order(:start_time)
    @categories = Current.user.categories.order(:name)
  rescue Date::Error, ArgumentError, TypeError
    redirect_to calendar_path
  end
end
