ENV["DATABASE_URL"] = "postgres://localhost:5432/flashdance_test"
require "api"

DB.loggers = []

module IntegrationHelpers
  def app
    Api.new
  end

  def json_response
    JSON.parse(last_response.body)
  end

  def last_status
    last_response.status
  end
end

RSpec.configure do |config|
  config.include IntegrationHelpers

  config.after do
    DB[:seats].delete
    DB[:rows].delete
    DB[:gigs].delete
  end
end
