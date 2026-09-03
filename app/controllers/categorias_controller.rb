class CategoriasController < ApplicationController
  before_action :set_categoria, only: [:edit, :update, :destroy]

  def index
    @categorias = Categoria.order(:nome)
  end

  def new
    @categoria = Categoria.new
  end

  def create
    @categoria = Categoria.new(categoria_params)

    if @categoria.save
      redirect_to categorias_path, notice: "Categoria criada."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @categoria.update(categoria_params)
      redirect_to categorias_path, notice: "Categoria atualizada."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @categoria.destroy
    redirect_to categorias_path, notice: "Categoria removida."
  end

  private

  def set_categoria
    @categoria = Categoria.find(params[:id])
  end

  def categoria_params
    params.require(:categoria).permit(:nome, :cor, :hora_inicio, :hora_fim)
  end
end
