class ShiftsController < ApplicationController
  before_action :set_shift, only: [:edit, :update, :destroy]

  def index
    @shifts = Current.user.shifts.order(:date, :start_time).includes(:category)
  end

  def new
    @shift = Current.user.shifts.new
    @categories = Current.user.categories.order(:name)
  end

  def create
    @shift = Current.user.shifts.new(shift_params)

    if @shift.save
      redirect_to destination_after_save, notice: "Plantão criado."
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
    @shift.destroy
    redirect_to destination_after_save, notice: "Plantão removido."
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
end
