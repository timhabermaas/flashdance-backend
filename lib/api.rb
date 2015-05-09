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

  before do
    headers "Access-Control-Allow-Origin" => "*"
    headers "Access-Control-Allow-Methods" => "GET,PUT,POST,DELETE"
    headers "Access-Control-Allow-Credentials" => "true"
    headers "Access-Control-Allow-Headers" => "Last-Event-Id, Origin, X-Requested-With, Content-Type, Accept, Authorization"

    headers "Content-Type" => "application/json; charset=utf-8"

    halt 200 if request.request_method == "OPTIONS"
  end

  not_found do
    status 404
    headers "Content-Type" => "application/json; charset=utf-8"
    body '{"error": "not found"}'
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

    if r["email"].nil? || r["email"].empty?
      status 422
      body JSON.generate({errors: [{attribute: "email", code: "missing_field", message: "missing attribute `email`"}]})
      return
    end

    if r["name"].nil? || r["name"].empty?
      status 422
      body JSON.generate({errors: [{attribute: "name", code: "missing_field", message: "missing attribute `name`"}]})
      return
    end

    if r["seatIds"].nil? || r["seatIds"].empty?
      status 422
      body JSON.generate({errors: [{attribute: "seatIds", code: "missing_field", message: "missing attribute `seatIds`"}]})
      return
    end

    r = r.merge(gig_id: params[:gig_id], seat_ids: r["seatIds"])
    begin
      order_id = @app.handle(Commands::SubmitOrder.new(r))

      status 201
      body JSON.generate({name: r["name"], id: order_id, email: r["email"], seatIds: r["seatIds"]})
    rescue App::SeatsReserved => e
      status 422
      body JSON.generate({errors: [{attribute: "seatIds", code: "already_exists", message: "Some seats are already reserved"}]})
    end
  end

  put "/orders/:order_id/pay" do
    begin
      @app.handle(Commands::PayOrder.new(order_id: params["order_id"]))
      status 200
      body JSON.generate({})
    rescue ArgumentError
      status 404
      body '{"error": "not found"}'
    end
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
