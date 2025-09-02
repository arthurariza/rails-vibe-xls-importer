# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

# Load all support files
Dir[Rails.root.join("test/support/**/*.rb")].each { |f| require f }

# Add more helper methods to be used by all tests here...
class ActiveSupport::TestCase
  # Run tests in parallel with specified workers
  parallelize(workers: :number_of_processors)

  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  fixtures :all
  
  # Include Excel fixture helper for all tests
  include ExcelFixtureHelper

  # Add more helper methods to be used by all tests here...
end
