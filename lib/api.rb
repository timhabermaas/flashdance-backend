require "sinatra/base"
require "json"
require "sequel"
require "logger"



class Api < Sinatra::Application
  set :show_exceptions, false
  set :raise_errors, true
  set :dump_errors, false

  configure :production do
    require "newrelic_rpm"
  end

  def initialize(app)
    super()
    @app = app
  end

  not_found do
    status 404
    headers "Content-Type" => "application/json; charset=utf-8"
    body '{"error": "not found"}'
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

  get "/gigs" do
    gigs = DBModels::Gig.order(:date)
    gigs = gigs.map { |g| ReadModels::Gig.new(g, @app.answer(Queries::GetFreeSeats.new(gig_id: g.id))) }
    body JSON.generate(gigs.map(&:serialize))
  end

  post "/gigs/:gig_id/orders" do
    r = JSON.parse(request.body.read)
    r = r.merge(gig_id: params[:gig_id], seat_ids: r["seatIds"])
    @app.handle(Commands::SubmitOrder.new(r))
    status 201
    body JSON.generate({})
  end

  get "/gigs/:gig_id/orders" do
    orders = @app.answer(Queries::ListOrdersForGig.new(gig_id: params[:gig_id]))

    body JSON.generate(orders.map(&:serialize))
  end

  get "/gigs/:gig_id/reservations" do
    reservations = @app.answer(Queries::ListReservationsForGig.new(gig_id: params[:gig_id]))

    body JSON.generate(reservations.map(&:serialize))
  end
end
