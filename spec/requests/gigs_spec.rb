require "spec_helper"
require "rack/test"

RSpec.describe "/gigs" do
  include Rack::Test::Methods

  before do
    id = internal_app.handle(Commands::CreateGig.new(title: "1. gig", date: DateTime.new(2014, 2, 3, 12, 30, 00, '+1'))).id
    other_id = internal_app.handle(Commands::CreateGig.new(title: "3. gig", date: DateTime.new(2014, 2, 5, 15, 30, 00, '+1'))).id
    internal_app.handle(Commands::CreateGig.new(title: "2. gig", date: DateTime.new(2014, 2, 4, 15, 30, 00, '+1')))

    3.times { create_seat(id) }
    create_seat(other_id)
    seat_id = create_seat(id).id
    order_id = internal_app.handle(Commands::StartOrder.new(name: "foo", email: "bar@cow.com"))
    internal_app.handle(Commands::ReserveSeat.new(order_id: order_id, seat_id: seat_id))

    get "/gigs"
  end

  it "responds with 200 Ok" do
    expect(last_status).to eq 200
  end

  it "returns all gigs ordered by date" do
    expect(json_response.size).to eq 3
    expect(json_response.map { |g| g["title"] }).to eq ["1. gig", "2. gig", "3. gig"]
    expect(json_response.first["id"]).to be_a(String)
    expect(DateTime.parse(json_response.first["date"])).to eq DateTime.new(2014, 2, 3, 11, 30)
  end

  it "returns the amount of free seats" do
    expect(json_response.first["freeSeats"]).to eq 3
  end
end
