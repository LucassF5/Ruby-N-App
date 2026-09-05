class Category < ApplicationRecord
  belongs_to :user
  has_many :shifts, dependent: :nullify

  validates :name, presence: true
  validates :color, presence: true
  validates :start_time, presence: true
  validates :end_time, presence: true
  validate :end_time_not_equal_to_start_time

  private

  def end_time_not_equal_to_start_time
    return if start_time.blank? || end_time.blank?

    errors.add(:end_time, "não pode ser igual ao horário de início") if end_time == start_time
  end
end
