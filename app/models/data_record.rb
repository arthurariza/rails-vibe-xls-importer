class DataRecord < ApplicationRecord
  belongs_to :import_template

  validates :import_template, presence: true
  validate :at_least_one_column_has_data

  # Get value for a specific column
  def column_value(column_number)
    send("column_#{column_number}")
  end

  # Set value for a specific column
  def set_column_value(column_number, value)
    send("column_#{column_number}=", value)
  end

  # Get all column values as an array
  def column_values
    (1..5).map { |i| column_value(i) }
  end

  # Get column values as hash with template headers as keys
  def data_hash
    return {} unless import_template.present?

    result = {}
    (1..5).each do |i|
      column_def = import_template.column_definition(i)
      next unless column_def.present?

      header = column_def["name"]
      value = column_value(i)
      result[header] = value if value.present?
    end
    result
  end

  private

  def at_least_one_column_has_data
    return unless column_values.all?(&:blank?)

    errors.add(:base, "At least one column must have data")
  end
end
