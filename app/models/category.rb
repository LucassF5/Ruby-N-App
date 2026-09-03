class Categoria < ApplicationRecord
  has_many :plantoes, dependent: :nullify

  validates :nome, presence: true
  validates :cor, presence: true
  validates :hora_inicio, presence: true
  validates :hora_fim, presence: true
  validate :hora_fim_depois_da_hora_inicio

  private

  def hora_fim_depois_da_hora_inicio
    return if hora_inicio.blank? || hora_fim.blank?

    errors.add(:hora_fim, "deve ser depois do horário de início") if hora_fim <= hora_inicio
  end
end
