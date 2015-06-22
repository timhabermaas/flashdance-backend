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

  def error_to_response(error)
    case error
    when Aggregates::Order::OrderAlreadyPaid
      status 400
      body JSON.generate(errors: [{message: "order already paid"}])
    when Aggregates::Order::OrderNotYetPaid
      status 400
      body JSON.generate(errors: [{message: "order not yet paid"}])
    when Aggregates::Order::SeatNotReserved
      status 400
      body JSON.generate(errors: [{message: "seat not reserved by order"}])
    when App::RecordNotFound
      status 404
      body JSON.generate(error: "not found")
    else
      status 400
    end
  end

  def result_to_response(result, &block)
    result.and_then(&block)
    result.on_error do |error|
      error_to_response error
      Error(UNIT)
    end
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
    order_id =
    result_to_response(@app.handle(Commands::StartOrder.new(name: r["name"], email: r["email"]))) do |order_id|
      status 201
      body JSON.generate({orderId: order_id})
      Ok(nil)
    end
  end

  # type can be "pickUpBeforehand" or "pickUpBoxOffice"
  # if address is set, it's automatically delivered
  put "/orders/:id/finish" do
    r = JSON.parse(request.body.read)
    if address = r["address"]
      c = Commands::FinishOrderWithAddress.new(street: address["street"], postal_code: address["postalCode"], city: address["city"], order_id: params[:id], reduced_count: r["reducedCount"])
      result_to_response(@app.handle(c)) do
        status 200
        body JSON.generate({})
        Ok(UNIT)
      end
    else
      c = Commands::FinishOrder.new(type: r["type"], order_id: params[:id], reduced_count: r["reducedCount"])
      result_to_response(@app.handle(c)) do
        status 200
        body JSON.generate({})
        Ok(UNIT)
      end
    end
  end

  put "/orders/:id/reservations/:seat_id" do
    c = Commands::ReserveSeat.new(order_id: params[:id], seat_id: params[:seat_id])
    result_to_response(@app.handle(c)) do
      status 200
      body JSON.generate({})
      Ok(nil)
    end
  end

  delete "/orders/:id/reservations/:seat_id" do
    c = Commands::FreeSeat.new(order_id: params[:id], seat_id: params[:seat_id])
    result_to_response(@app.handle(c)) do
      status 200
      body JSON.generate({})
      Ok(nil)
    end
  end

  delete "/orders/:id" do
    result_to_response(@app.handle(Commands::CancelOrder.new(order_id: params[:id]))) do
      status 200
      body JSON.generate({})
      Ok(nil)
    end
  end

  put "/orders/:order_id/pay" do
    result_to_response(@app.handle(Commands::PayOrder.new(order_id: params["order_id"]))) do
      status 200
      body JSON.generate({})
      Ok(nil)
    end
  end

  put "/orders/:order_id/unpay" do
    result_to_response(@app.handle(Commands::UnpayOrder.new(order_id: params["order_id"]))) do
      status 200
      body JSON.generate({})
      Ok(nil)
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
