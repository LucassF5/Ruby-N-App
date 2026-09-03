class PlantoesController < ApplicationController
  before_action :set_plantao, only: [:edit, :update, :destroy]

  def index
    @plantoes = Plantao.order(:data, :hora_inicio)
  end

  def new
    @plantao = Plantao.new
  end

  def create
    @plantao = Plantao.new(plantao_params)

    if @plantao.save
      redirect_to root_path, notice: "Plantão criado."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @plantao.update(plantao_params)
      redirect_to root_path, notice: "Plantão atualizado."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @plantao.destroy
    redirect_to root_path, notice: "Plantão removido."
  end

  private

  def set_plantao
    @plantao = Plantao.find(params[:id])
  end

  def plantao_params
    params.require(:plantao).permit(:data, :hora_inicio, :hora_fim, :local, :observacao)
  end
end
