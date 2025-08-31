# frozen_string_literal: true

module ApplicationHelper
  include Pagy::Frontend

  def format_column_value(value, data_type)
    return "" if value.blank?

    case data_type
    when "number"
      number_with_delimiter(value)
    when "date"
      begin
        Date.parse(value).strftime("%m/%d/%Y")
      rescue StandardError
        value
      end
    when "boolean"
      value == "true" ? "Yes" : "No"
    else
      value.to_s
    end
  end
end
