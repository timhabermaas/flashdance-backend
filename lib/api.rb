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
    headers "Access-Control-Allow-Headers" => "X-User, X-Password, Last-Event-Id, Origin, X-Requested-With, Content-Type, Accept, Authorization"

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
    body JSON.generate(error: "not found")
  end

  post "/login" do
    r = JSON.parse(request.body.read)
    if role = @app.login(r["user"], r["password"])
      status 200
      body JSON.generate(role: role)
    else
      status 401
    end
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

  # type can be "pickUpBeforehand" or "pickUpBoxOffice"
  # if address is set, it's automatically delivered
  put "/orders/:id/finish" do
    r = JSON.parse(request.body.read)
    begin
      if address = r["address"]
        @app.handle(Commands::FinishOrderWithAddress.new(street: address["street"], postal_code: address["postalCode"], city: address["city"], order_id: params[:id], reduced_count: r["reducedCount"]))
      else
        @app.handle(Commands::FinishOrder.new(type: r["type"], order_id: params[:id], reduced_count: r["reducedCount"]))
      end
      status 200
      body JSON.generate({})
    rescue Aggregates::Order::CantFinishOrder
      status 400
    end
  end

  put "/orders/:id/reservations/:seat_id" do
    begin
      @app.handle(Commands::ReserveSeat.new(order_id: params[:id], seat_id: params[:seat_id]))
      status 200
      body JSON.generate({})
    rescue Aggregates::Gig::SeatAlreadyReserved => e
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

  delete "/orders/:id" do
    @app.handle(Commands::CancelOrder.new(order_id: params[:id]))
    status 200
    body JSON.generate({})
  end

  put "/orders/:order_id/pay" do
    begin
      @app.handle(Commands::PayOrder.new(order_id: params["order_id"]))
      status 200
      body JSON.generate({})
    rescue Aggregates::Order::OrderAlreadyPaid
      status 400
      body JSON.generate(errors: [{message: "order already paid"}])
    end
  end

  put "/orders/:order_id/unpay" do
    begin
      @app.handle(Commands::UnpayOrder.new(order_id: params["order_id"]))
      status 200
      body JSON.generate({})
    rescue Aggregates::Order::OrderNotYetPaid
      status 400
      body JSON.generate(errors: [{message: "order not yet paid"}])
    end
  end

  get "/orders" do
    orders = @app.answer(Queries::ListFinishedOrders.new)

    body JSON.generate(orders.map(&:serialize))
  end

  get "/unfinished_orders" do
    orders = @app.answer(Queries::ListObsoleteOrders.new)

    body JSON.generate(orders.map(&:serialize))
  end

  get "/gigs/:gig_id/reservations" do
    reservations = @app.answer(Queries::ListReservationsForGig.new(gig_id: params[:gig_id]))

    body JSON.generate(reservations.map(&:serialize))
  end
end
