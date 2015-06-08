require "sinatra/base"
require "json"
require "sequel"
require "logger"

require "app"



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

  error App::RecordNotFound do
    status 404
  end

  get "/gigs/:gig_id/seats" do
    if DBModels::Gig[params[:gig_id]]
      status 200
      seats = @app.answer(Queries::ListSeats.new(gig_id: params[:gig_id]))
      rows = @app.answer(Queries::ListRows.new(gig_id: params[:gig_id])).map do |r|
        {y: r[:y], number: r[:number]}
      end
      seats = seats.map do |s|
        {x: s[:x], number: s[:number], row: s[:row_number], id: s[:id], usable: s[:usable]}
      end
      body JSON.generate({seats: seats, rows: rows})
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

  post "/orders" do
    r = JSON.parse(request.body.read)
    order_id = @app.handle(Commands::StartOrder.new(name: r["name"], email: r["email"]))
    status 201
    body JSON.generate({orderId: order_id})
  end

  put "/orders/:id/reservations/:seat_id" do
    begin
      @app.handle(Commands::ReserveSeat.new(order_id: params[:id], seat_id: params[:seat_id]))
      status 200
      body JSON.generate({})
    rescue App::SeatAlreadyReserved => e
      status 400
    end
  end

  delete "/orders/:id/reservations/:seat_id" do
    begin
      @app.handle(Commands::FreeSeat.new(order_id: params[:id], seat_id: params[:seat_id]))
      status 200
      body JSON.generate({})
    rescue App::SeatNotReserved => e
      status 400
      body JSON.generate(errors: [{message: "seat not reserved by order"}])
    end
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

    if r["reducedCount"].nil?
      status 422
      body JSON.generate({errors: [{attribute: "reducedCount", code: "missing_field", message: "missing attribute `reducedCount`"}]})
      return
    end

    if r["seatIds"].nil? || r["seatIds"].empty?
      status 422
      body JSON.generate({errors: [{attribute: "seatIds", code: "missing_field", message: "missing attribute `seatIds`"}]})
      return
    end

    r = r.merge(gig_id: params[:gig_id], seat_ids: r["seatIds"], reduced_count: r["reducedCount"])
    begin
      order_id = @app.handle(Commands::SubmitOrder.new(r))

      status 201
      body JSON.generate({name: r["name"], id: order_id, email: r["email"], seatIds: r["seatIds"], reducedCount: r["reducedCount"]})
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
