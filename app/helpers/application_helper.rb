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

  def status_indicator_classes(status)
    case status.to_sym
    when :pending
      "bg-gray-100 text-gray-600"
    when :processing
      "bg-blue-100 text-blue-600"
    when :completed
      "bg-green-100 text-green-600"
    when :failed
      "bg-red-100 text-red-600"
    else
      "bg-gray-100 text-gray-500"
    end
  end

  def status_icon_svg(status)
    case status.to_sym
    when :pending
      '<svg class="h-6 w-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"></path>
      </svg>'.html_safe
    when :processing
      '<svg class="animate-spin h-6 w-6" fill="none" viewBox="0 0 24 24">
        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
      </svg>'.html_safe
    when :completed
      '<svg class="h-6 w-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"></path>
      </svg>'.html_safe
    when :failed
      '<svg class="h-6 w-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
      </svg>'.html_safe
    else
      '<svg class="h-6 w-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8.228 9c.549-1.165 2.03-2 3.772-2 2.21 0 4 1.343 4 3 0 1.4-1.278 2.575-3.006 2.907-.542.104-.994.54-.994 1.093m0 3h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
      </svg>'.html_safe
    end
  end
end
