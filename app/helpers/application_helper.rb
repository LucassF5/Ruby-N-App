module ApplicationHelper
  PT_WEEKDAYS_SHORT = %w[Dom Seg Ter Qua Qui Sex Sáb].freeze
  PT_WEEKDAYS_FULL = %w[Domingo Segunda-feira Terça-feira Quarta-feira Quinta-feira Sexta-feira Sábado].freeze
  PT_MONTHS = %w[janeiro fevereiro março abril maio junho julho agosto setembro outubro novembro dezembro].freeze

  def weekday_abbr(date)
    PT_WEEKDAYS_SHORT[date.wday]
  end

  def weekday_full(date)
    PT_WEEKDAYS_FULL[date.wday]
  end

  def pt_full_date(date)
    "#{date.day} de #{PT_MONTHS[date.month - 1]} de #{date.year}"
  end

  def relative_day_label(date)
    case (date - Date.current).to_i
    when 0 then "Hoje"
    when 1 then "Amanhã"
    else "Em #{(date - Date.current).to_i} dias"
    end
  end
end
