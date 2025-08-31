# frozen_string_literal: true

class TemplateColumn < ApplicationRecord
  belongs_to :import_template
  has_many :data_record_values, dependent: :destroy

  validates :name, presence: true
  validates :data_type, presence: true, inclusion: { in: %w[string number date boolean] }
  validates :column_number, presence: true, numericality: { greater_than: 0 }
  validates :column_number, uniqueness: { scope: :import_template_id }

  scope :ordered, -> { order(:column_number) }

  before_save :ensure_column_number_sequence

  private

  def ensure_column_number_sequence
    return if column_number.present?

    max_column_number = import_template.template_columns.maximum(:column_number) || 0
    self.column_number = max_column_number + 1
  end
end
