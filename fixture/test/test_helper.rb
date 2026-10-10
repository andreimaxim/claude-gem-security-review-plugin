ENV["RAILS_ENV"] = "test"
ENV["NOTEBOOK_DB"] = File.expand_path("../db/test.sqlite3", __dir__)
require_relative "../config/environment"
require "rails/test_help"

class ActiveSupport::TestCase
  fixtures :all
end
