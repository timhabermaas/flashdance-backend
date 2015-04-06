require "api"
require "app"
require "commands"

module IntegrationHelpers
  def internal_app
    App.new("postgres://localhost:5432/flashdance_test", false)
  end

  def app
    Api.new internal_app
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
    internal_app.clean_db!
  end
end
