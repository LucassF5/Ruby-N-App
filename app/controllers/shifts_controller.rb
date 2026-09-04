class ShiftsController < ApplicationController
  before_action :set_shift, only: [:edit, :update, :destroy]

  def index
    @shifts = Shift.order(:date, :start_time).includes(:category)
  end

  def new
    @shift = Shift.new
    @categories = Category.order(:name)
  end

  def create
    @shift = Shift.new(shift_params.merge(user: Current.user))

    if @shift.save
      redirect_to destination_after_save, notice: "Plantão criado."
    else
      @categories = Category.order(:name)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @categories = Category.order(:name)
  end

  def update
    if @shift.update(shift_params)
      redirect_to destination_after_save, notice: "Plantão atualizado."
    else
      @categories = Category.order(:name)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @shift.destroy
    redirect_to destination_after_save, notice: "Plantão removido."
  end

  private

  def set_shift
    @shift = Shift.find(params[:id])
  end

  def shift_params
    params.require(:shift).permit(:date, :start_time, :end_time, :location, :notes, :category_id)
  end

  def destination_after_save
    return_to = params[:return_to]
    return_to.present? && return_to.start_with?("/") && !return_to.start_with?("//") ? return_to : root_path
  end
end
