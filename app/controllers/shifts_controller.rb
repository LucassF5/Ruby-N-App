class ShiftsController < ApplicationController
  before_action :set_shift, only: [:edit, :update, :destroy]

  def index
    @shifts = Current.user.shifts.order(:date, :start_time).includes(:category)
    @next_shift = Current.user.shifts.where(date: Date.current..).order(:date, :start_time).first
    @week_days = (Date.current..(Date.current + 4.days)).to_a
    @colors_by_day = Shift.category_colors_by_date(Current.user, @week_days.first..@week_days.last)
  end

  def new
    @shift = Current.user.shifts.new
    @categories = Current.user.categories.order(:name)
  end

  def create
    @shift = Current.user.shifts.new(shift_params)

    if @shift.save
      respond_to do |format|
        format.turbo_stream do
          if from_calendar_day?
            render turbo_stream: calendar_day_streams(@shift.date)
          else
            redirect_to destination_after_save, notice: "Plantão criado."
          end
        end
        format.html { redirect_to destination_after_save, notice: "Plantão criado." }
      end
    else
      @categories = Current.user.categories.order(:name)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @categories = Current.user.categories.order(:name)
  end

  def update
    if @shift.update(shift_params)
      redirect_to destination_after_save, notice: "Plantão atualizado."
    else
      @categories = Current.user.categories.order(:name)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    date = @shift.date
    @shift.destroy

    respond_to do |format|
      format.turbo_stream do
        if from_calendar_day?
          render turbo_stream: calendar_day_streams(date)
        else
          redirect_to destination_after_save, notice: "Plantão removido."
        end
      end
      format.html { redirect_to destination_after_save, notice: "Plantão removido." }
    end
  end

  private

  def set_shift
    @shift = Current.user.shifts.find(params[:id])
  end

  def shift_params
    params.require(:shift).permit(:date, :start_time, :end_time, :location, :notes, :category_id)
  end

  def destination_after_save
    return_to = params[:return_to]
    return_to.present? && return_to.start_with?("/") && !return_to.start_with?("//") ? return_to : root_path
  end

  def from_calendar_day?
    params[:return_to].present? && params[:return_to].start_with?("/calendar/")
  end

  def calendar_day_streams(date)
    @date = date
    @shifts = Current.user.shifts.where(date: @date).includes(:category).order(:start_time)
    @categories = Current.user.categories.order(:name)

    calendar = CalendarMonth.new(Current.user, date: @date)
    @month = calendar.month
    @weeks = calendar.weeks
    @colors_by_day = calendar.colors_by_day

    week_days = (Date.current..(Date.current + 4.days)).to_a

    [
      turbo_stream.replace("day_modal", template: "calendar/day"),
      turbo_stream.replace("calendar_month", partial: "calendar/month_grid"),
      turbo_stream.replace("next_shift_card", partial: "shifts/next_shift_card",
        locals: { next_shift: Current.user.shifts.where(date: Date.current..).order(:date, :start_time).first }),
      turbo_stream.replace("week_strip", partial: "shifts/week_strip",
        locals: { week_days: week_days, colors_by_day: Shift.category_colors_by_date(Current.user, week_days.first..week_days.last) })
    ]
  end
end
