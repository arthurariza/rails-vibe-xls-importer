# frozen_string_literal: true

class DataRecord < ApplicationRecord
  belongs_to :import_template, counter_cache: :data_records_count
  has_many :data_record_values, dependent: :destroy
  accepts_nested_attributes_for :data_record_values

  validate :at_least_one_column_has_data

  # Get value for a specific template column
  def value_for_column(template_column)
    data_record_values.find_by(template_column: template_column)&.value
  end

  # Set value for a specific template column
  def set_value_for_column(template_column, value)
    record_value = data_record_values.find_or_initialize_by(template_column: template_column)
    record_value.value = value
    record_value.save!
  end

  # Get all column values as an array (ordered by column_number)
  def column_values
    import_template.template_columns.ordered.map do |template_column|
      value_for_column(template_column)
    end
  end

  # Get column values as hash with template headers as keys
  def data_hash
    return {} if import_template.blank?

    result = {}
    import_template.template_columns.includes(:data_record_values).find_each do |template_column|
      value = value_for_column(template_column)
      result[template_column.name] = value if value.present?
    end
    result
  end

  # Legacy method for backward compatibility - get value by column number
  def column_value(column_number)
    template_column = import_template.template_columns.find_by(column_number: column_number)
    return nil unless template_column

    value_for_column(template_column)
  end

  # Legacy method for backward compatibility - set value by column number
  def set_column_value(column_number, value)
    template_column = import_template.template_columns.find_by(column_number: column_number)
    return false unless template_column

    set_value_for_column(template_column, value)
    true
  end

  private

  def at_least_one_column_has_data
    return unless data_record_values.joins(:template_column).where.not(value: [nil, ""]).empty? && persisted?

    errors.add(:base, "At least one column must have data")
  end
end
