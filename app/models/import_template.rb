# frozen_string_literal: true

class ImportTemplate < ApplicationRecord
  belongs_to :user
  has_many :data_records, dependent: :destroy

  validates :name, presence: true, uniqueness: true
  # Allow empty column_definitions for flexibility
  validate :validate_column_definitions

  # Serialize column_definitions as JSON
  serialize :column_definitions, coder: JSON

  # Get column headers in order
  def column_headers
    return [] if column_definitions.blank?

    (1..5).filter_map do |i|
      column_definitions["column_#{i}"]&.dig("name")
    end
  end

  # Get column definition for a specific column
  def column_definition(column_number)
    return nil if column_definitions.blank?

    column_definitions["column_#{column_number}"]
  end

  private

  def validate_column_definitions
    return if column_definitions.blank?

    unless column_definitions.is_a?(Hash)
      errors.add(:column_definitions, "must be a valid JSON object")
      return
    end

    # Check that we have definitions for columns 1-5
    (1..5).each do |i|
      column_key = "column_#{i}"
      column_def = column_definitions[column_key]

      next if column_def.blank? # Allow empty columns

      unless column_def.is_a?(Hash)
        errors.add(:column_definitions, "column #{i} must be an object")
        next
      end

      errors.add(:column_definitions, "column #{i} must have a name") if column_def["name"].blank?

      unless %w[string number date boolean].include?(column_def["data_type"])
        errors.add(:column_definitions, "column #{i} must have a valid data_type (string, number, date, boolean)")
      end
    end
  end
end
