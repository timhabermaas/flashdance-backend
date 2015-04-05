require "sinatra/base"
require "json"
require "sequel"
require "logger"



class Api < Sinatra::Application
  def initialize(app)
    @app = app
    super()
  end

  before do
    headers "Access-Control-Allow-Origin" => "*"
    headers "Content-Type" => "application/json; charset=utf-8"
  end

  get "/gigs/:gig_id/seats" do
    if DBModels::Gig[params[:gig_id]]
      status 200
      body JSON.generate({seats: DBModels::Seat.eager(:row).all.map(&:serialize), rows: DBModels::Row.all.map(&:serialize)})
    else
      status 404
      body '{"error": "not found"}'
    end
  end
end
