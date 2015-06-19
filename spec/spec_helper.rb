ENV["RACK_ENV"] = "test"

require "api"
require "app"
require "commands"

module IntegrationHelpers
  def internal_app
    @app ||= App.new("postgres://localhost:5432/flashdance_test", "user123", "admin123", false)
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

module FixtureHelpers
  def create_gig
    internal_app.handle(Commands::CreateGig.new(title: "foo", date: DateTime.new(2014, 1, 2))).unwrap.id
  end

  def create_seat(gig_id)
    row = internal_app.handle(Commands::CreateRow.new(y: 1, number: 2, gig_id: gig_id)).unwrap
    internal_app.handle(Commands::CreateSeat.new(x: 1, number: 3, row_id: row.id, usable: true)).unwrap
  end
end

RSpec.configure do |config|
  config.include IntegrationHelpers
  config.include FixtureHelpers

  config.before do
    internal_app.load_models!
    internal_app.load_events!
  end

  config.after do
    internal_app.clean_db!
  end
end
