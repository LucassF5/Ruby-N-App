class Plantao < ApplicationRecord
  belongs_to :categoria, optional: true

  before_validation :aplicar_horario_da_categoria

  validates :data, presence: true
  validates :hora_inicio, presence: true
  validates :hora_fim, presence: true
  validate :hora_fim_depois_da_hora_inicio

  private

  def aplicar_horario_da_categoria
    return unless categoria

    self.hora_inicio ||= categoria.hora_inicio
    self.hora_fim ||= categoria.hora_fim
  end

  def hora_fim_depois_da_hora_inicio
    return if hora_inicio.blank? || hora_fim.blank?

    errors.add(:hora_fim, "deve ser depois do horário de início") if hora_fim <= hora_inicio
  end
end
