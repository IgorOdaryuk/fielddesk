ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require_relative "test_helpers/session_test_helper"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Test code runs as Sunshine; requests resolve their own account.
    setup { ActsAsTenant.test_tenant = accounts(:sunshine) }
    teardown { ActsAsTenant.test_tenant = nil }
  end
end
