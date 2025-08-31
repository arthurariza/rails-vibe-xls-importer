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
    template_headers = import_template.column_headers.map(&:downcase)

    # Check for missing required headers
    missing_normalized_headers = template_headers - excel_headers
    validation_result.missing_headers = missing_normalized_headers

    # Check for extra headers
    extra_headers = excel_headers - template_headers
    validation_result.extra_headers = extra_headers

    # Create mapping of excel headers to template columns
    create_header_mapping

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
    template_headers = import_template.column_headers

    excel_headers.each_with_index do |excel_header, index|
      template_header = template_headers.find { |h| h.downcase == excel_header }
      next unless template_header

      # Find which column number this header belongs to
      (1..5).each do |col_num|
        column_def = import_template.column_definition(col_num)
        next unless column_def&.dig("name")&.downcase == excel_header

        # Adjust Excel column index to account for ID column (if present)
        excel_col_index = @has_id_column ? index + 1 : index
        mapping[excel_col_index] = col_num
        break
      end
    end

    validation_result.header_mapping = mapping
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

    def initialize
      @valid = false
      @missing_headers = []
      @extra_headers = []
      @header_mapping = {}
      @suggested_mappings = {}
      @import_template = nil
    end

    def errors
      errors = []
      if missing_headers.any?
        # Show the actual template headers, not the normalized ones
        actual_missing_headers = find_actual_template_headers(missing_headers)
        errors << "Missing required headers: #{actual_missing_headers.join(', ')}"
      end
      errors << "Extra headers found: #{extra_headers.join(', ')}" if extra_headers.any?
      errors
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
