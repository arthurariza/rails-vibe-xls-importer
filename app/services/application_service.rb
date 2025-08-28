# frozen_string_literal: true

class ApplicationService
  class << self
    def call(...)
      service = new
      service.call(...)
      service.response
    end
  end

  def initialize
    @errors = []
    @result = nil
  end

  def call
    raise NotImplementedError
  end

  def response
    @response ||= ServiceResponse.new(@result, @errors)
  end

  protected

  def add_error(message)
    @errors << message
  end

  def add_result(result)
    @result = result
  end
end

class ServiceResponse
  attr_reader :result, :errors

  def initialize(result, errors)
    @result = result
    @errors = errors
  end

  def ok?
    errors.empty?
  end
end
