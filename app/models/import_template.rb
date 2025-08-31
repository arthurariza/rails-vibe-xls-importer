# frozen_string_literal: true

class ImportTemplate < ApplicationRecord
  belongs_to :user
  has_many :data_records, dependent: :destroy
  has_many :template_columns, -> { ordered }, dependent: :destroy

  validates :name, presence: true, uniqueness: true
  # validate :at_least_one_column  # Disabled for now - business rule that templates can be created empty initially

  # Get column headers in order using new template_columns
  def column_headers
    template_columns.pluck(:name)
  end

  # Get column definition for a specific column (by number or column object)
  def column_definition(column_number)
    if column_number.is_a?(Integer)
      template_columns.find_by(column_number: column_number)
    else
      column_number # Already a template column
    end
  end

  # Helper methods for managing dynamic columns
  def add_column(name:, data_type:, required: false)
    max_number = template_columns.maximum(:column_number) || 0
    template_columns.create!(
      name: name,
      data_type: data_type,
      required: required,
      column_number: max_number + 1
    )
  end

  def remove_column(column_number)
    column = template_columns.find_by(column_number: column_number)
    return false unless column

    column.destroy
    reorder_columns
    true
  end

  def reorder_columns
    template_columns.ordered.each_with_index do |column, index|
      column.update_column(:column_number, index + 1)
    end
  end

  private

  def at_least_one_column
    return unless template_columns.empty? && persisted?

    errors.add(:base, "Template must have at least one column")
  end
end
