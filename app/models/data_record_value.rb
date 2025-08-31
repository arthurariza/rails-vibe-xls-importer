# frozen_string_literal: true

class DataRecordValue < ApplicationRecord
  belongs_to :data_record
  belongs_to :template_column

  validates :data_record_id, uniqueness: { scope: :template_column_id }

  scope :for_column, lambda { |column_number|
    joins(:template_column).where(template_columns: { column_number: column_number })
  }

  def column_name
    template_column.name
  end

  def column_type
    template_column.data_type
  end
end
