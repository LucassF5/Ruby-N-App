module ApplicationHelper
  PT_WEEKDAYS_SHORT = %w[Dom Seg Ter Qua Qui Sex Sáb].freeze
  PT_MONTHS = %w[janeiro fevereiro março abril maio junho julho agosto setembro outubro novembro dezembro].freeze

  def weekday_abbr(date)
    PT_WEEKDAYS_SHORT[date.wday]
  end

  def pt_full_date(date)
    "#{date.day} de #{PT_MONTHS[date.month - 1]} de #{date.year}"
  end
end
