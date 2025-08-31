# frozen_string_literal: true

require "test_helper"

class HeaderValidationServiceTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @template = import_templates(:one)
  end

  test "should validate matching headers" do
    excel_headers = %w[Name Age Email]
    service = HeaderValidationService.new(excel_headers, @template)
    result = service.validate_headers

    assert result.valid
    assert_empty result.missing_headers
    assert_empty result.extra_headers
    assert_equal 3, result.header_mapping.size
  end

  test "should handle case insensitive headers" do
    excel_headers = %w[name AGE Email]
    service = HeaderValidationService.new(excel_headers, @template)
    result = service.validate_headers

    assert result.valid
    assert_empty result.missing_headers
    assert_empty result.extra_headers
  end

  test "should detect missing headers" do
    excel_headers = %w[Name Age] # Missing Email
    service = HeaderValidationService.new(excel_headers, @template)
    result = service.validate_headers

    assert_not result.valid
    assert_includes result.missing_headers, "email"
    assert_empty result.extra_headers
  end

  test "should detect extra headers" do
    excel_headers = %w[Name Age Email Phone] # Phone is extra
    service = HeaderValidationService.new(excel_headers, @template)
    result = service.validate_headers

    assert result.valid # Extra headers don't invalidate, missing ones do
    assert_empty result.missing_headers
    assert_includes result.extra_headers, "phone"
  end

  test "should suggest mappings for similar headers" do
    excel_headers = ["Full Name", "Years Old", "E-mail"]
    service = HeaderValidationService.new(excel_headers, @template)
    result = service.suggest_mappings

    # Should suggest some mappings based on similarity
    assert_predicate result.suggested_mappings, :any?
  end

  test "should handle empty excel headers" do
    excel_headers = []
    service = HeaderValidationService.new(excel_headers, @template)
    result = service.validate_headers

    assert_not result.valid
    assert_equal 3, result.missing_headers.size
    assert_empty result.extra_headers
  end

  test "should handle nil and empty string headers" do
    excel_headers = ["Name", nil, "", "Age"]
    service = HeaderValidationService.new(excel_headers, @template)
    result = service.validate_headers

    # Should normalize and ignore nil/empty headers
    assert_not result.valid # Will be missing Email
    assert_includes result.missing_headers, "email"
  end

  test "should create proper header mapping" do
    excel_headers = %w[Name Age Email]
    service = HeaderValidationService.new(excel_headers, @template)
    result = service.validate_headers

    # Check that mapping correctly maps excel column indexes to template columns
    assert_equal 1, result.header_mapping[0].column_number # First excel column maps to column_1
    assert_equal 2, result.header_mapping[1].column_number # Second excel column maps to column_2  
    assert_equal 3, result.header_mapping[2].column_number # Third excel column maps to column_3
    assert_equal "Name", result.header_mapping[0].name
    assert_equal "Age", result.header_mapping[1].name
    assert_equal "Email", result.header_mapping[2].name
  end
end
