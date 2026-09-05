class Shift < ApplicationRecord
  belongs_to :user
  belongs_to :category, optional: true

  before_validation :apply_category_schedule

  validates :date, presence: true
  validates :start_time, presence: true
  validates :end_time, presence: true
  validate :end_time_not_equal_to_start_time
  validates :category, inclusion: { in: ->(shift) { shift.user&.categories || [] } }, allow_nil: true

  def self.category_colors_by_date(user, range)
    user.shifts.where(date: range)
        .includes(:category)
        .group_by(&:date)
        .transform_values do |shifts|
          shifts.uniq { |s| s.category_id }.map { |s| s.category&.color || "#94a3b8" }
        end
  end

  private

  def apply_category_schedule
    return unless category

    self.start_time ||= category.start_time
    self.end_time ||= category.end_time
  end

  def end_time_not_equal_to_start_time
    return if start_time.blank? || end_time.blank?

    errors.add(:end_time, "não pode ser igual ao horário de início") if end_time == start_time
  end
end
