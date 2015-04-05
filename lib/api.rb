require "sinatra/base"
require "json"
require "sequel"
require "logger"

database_url = ENV.fetch("DATABASE_URL") { "postgres://localhost:5432/flashdance_development" }
DB = Sequel.connect(database_url, :loggers => [Logger.new($stdout)])

require "models"

class Api < Sinatra::Application
  before do
    headers "Access-Control-Allow-Origin" => "*"
    headers "Content-Type" => "application/json; charset=utf-8"
  end

  get "/gigs/:gig_id/seats" do
    status 200

    body JSON.generate({seats: DBModels::Seat.eager(:row).all.map(&:serialize), rows: DBModels::Row.all.map(&:serialize)})
  end
end
