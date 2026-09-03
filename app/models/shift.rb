class Shift < ApplicationRecord
  belongs_to :category, optional: true

  before_validation :apply_category_schedule

  validates :date, presence: true
  validates :start_time, presence: true
  validates :end_time, presence: true
  validate :end_time_after_start_time

  private

  def apply_category_schedule
    return unless category

    self.start_time ||= category.start_time
    self.end_time ||= category.end_time
  end

  def end_time_after_start_time
    return if start_time.blank? || end_time.blank?

    errors.add(:end_time, "deve ser depois do horário de início") if end_time <= start_time
  end
end
