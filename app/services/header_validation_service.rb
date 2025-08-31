# frozen_string_literal: true

class HeaderValidationService < ApplicationService
  attr_reader :excel_headers, :import_template, :validation_result

  def initialize(excel_headers, import_template, has_id_column = false)
    @excel_headers = normalize_headers(excel_headers)
    @import_template = import_template
    @has_id_column = has_id_column
    @validation_result = ValidationResult.new
    @validation_result.import_template = import_template
  end

  def validate_headers
    # Handle case where template has no columns configured
    if import_template.template_columns.empty?
      validation_result.valid = false
      validation_result.custom_errors << "Template has no columns configured. Please add columns to the template first."
      return validation_result
    end

    template_headers = import_template.column_headers.map(&:downcase)
    
    # Handle case where Excel file has no headers
    if excel_headers.empty?
      validation_result.valid = false
      validation_result.missing_headers = template_headers
      message = "Excel file has no headers. Please ensure the first row contains column headers."
      validation_result.custom_errors << message
      return validation_result
    end

    # Check for missing required headers
    missing_normalized_headers = template_headers - excel_headers
    validation_result.missing_headers = missing_normalized_headers

    # Check for extra headers (only show warning, don't fail validation)
    extra_headers = excel_headers - template_headers
    validation_result.extra_headers = extra_headers

    # Create mapping of excel headers to template columns
    create_header_mapping

    # Check column order matching (optional validation - warns but doesn't fail)
    validate_column_order

    # Validation succeeds if all required headers are present
    validation_result.valid = missing_normalized_headers.empty?
    validation_result
  end

  def suggest_mappings
    template_headers = import_template.column_headers
    suggestions = {}

    excel_headers.each do |excel_header|
      best_match = find_best_match(excel_header, template_headers)
      suggestions[excel_header] = best_match if best_match
    end

    validation_result.suggested_mappings = suggestions
    validation_result
  end

  private

  def normalize_headers(headers)
    headers.compact.map do |header|
      header.to_s.strip.downcase
    end
  end

  def create_header_mapping
    mapping = {}
    template_columns = import_template.template_columns.includes(:import_template)

    excel_headers.each_with_index do |excel_header, index|
      # Find the template column with matching name
      template_column = template_columns.find { |col| col.name.downcase == excel_header }
      next unless template_column

      # Map excel column index to template column object
      mapping[index] = template_column
    end

    validation_result.header_mapping = mapping
  end

  def validate_column_order
    # Only validate order if all required headers are present
    return if validation_result.missing_headers.any?

    template_headers = import_template.column_headers.map(&:downcase)

    # Find the order of matching headers in Excel
    excel_order = []
    template_headers.each do |template_header|
      excel_index = excel_headers.index(template_header)
      excel_order << excel_index if excel_index
    end

    # Check if the Excel headers are in the same order as template
    expected_order = excel_order.sort
    return unless excel_order != expected_order

    template_order = import_template.column_headers.join(", ")
    excel_found_order = excel_order.map { |idx| excel_headers[idx].titleize }.join(", ")

    message = "Column order mismatch: Expected order '#{template_order}' " \
              "but found '#{excel_found_order}'. Data will still import correctly."
    validation_result.custom_errors << message
  end

  def find_best_match(excel_header, template_headers)
    # Simple fuzzy matching - find closest match
    best_match = nil
    best_score = 0

    template_headers.each do |template_header|
      score = calculate_similarity(excel_header, template_header.downcase)
      if score > best_score && score > 0.7 # 70% similarity threshold
        best_score = score
        best_match = template_header
      end
    end

    best_match
  end

  def calculate_similarity(str1, str2)
    # Simple similarity calculation using Levenshtein distance
    return 1.0 if str1 == str2
    return 0.0 if str1.empty? || str2.empty?

    max_length = [str1.length, str2.length].max
    distance = levenshtein_distance(str1, str2)

    (max_length - distance).to_f / max_length
  end

  def levenshtein_distance(str1, str2)
    # Simple Levenshtein distance implementation
    return str2.length if str1.empty?
    return str1.length if str2.empty?

    matrix = Array.new(str1.length + 1) { Array.new(str2.length + 1) }

    (0..str1.length).each { |i| matrix[i][0] = i }
    (0..str2.length).each { |j| matrix[0][j] = j }

    (1..str1.length).each do |i|
      (1..str2.length).each do |j|
        cost = str1[i - 1] == str2[j - 1] ? 0 : 1
        matrix[i][j] = [
          matrix[i - 1][j] + 1,     # deletion
          matrix[i][j - 1] + 1,     # insertion
          matrix[i - 1][j - 1] + cost # substitution
        ].min
      end
    end

    matrix[str1.length][str2.length]
  end

  class ValidationResult
    attr_accessor :valid, :missing_headers, :extra_headers, :header_mapping, :suggested_mappings, :import_template
    attr_reader :custom_errors

    def initialize
      @valid = false
      @missing_headers = []
      @extra_headers = []
      @header_mapping = {}
      @suggested_mappings = {}
      @import_template = nil
      @custom_errors = []
    end

    def errors
      # Combine custom errors with missing/extra header errors
      all_errors = custom_errors.dup

      if missing_headers.any?
        # Show the actual template headers, not the normalized ones
        actual_missing_headers = find_actual_template_headers(missing_headers)
        template_name = import_template&.name ? " in template '#{import_template.name}'" : ""
        all_errors << "Missing required headers#{template_name}: #{actual_missing_headers.join(', ')}"
      end

      all_errors << "Extra headers found (will be ignored): #{extra_headers.join(', ')}" if extra_headers.any?

      all_errors
    end

    def has_suggestions?
      suggested_mappings.any?
    end

    private

    def find_actual_template_headers(normalized_missing_headers)
      return normalized_missing_headers unless import_template

      actual_headers = []
      normalized_missing_headers.each do |normalized_header|
        # Find the actual header that matches this normalized one
        actual_header = import_template.column_headers.find { |h| h.downcase == normalized_header }
        actual_headers << (actual_header || normalized_header)
      end
      actual_headers
    end
  end
end
