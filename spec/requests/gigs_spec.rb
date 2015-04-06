require "spec_helper"
require "rack/test"

RSpec.describe "/gigs" do
  include Rack::Test::Methods

  before do
    internal_app.handle(Commands::CreateGig.new(title: "1. gig", date: Time.utc(2014, 2, 3, 12, 30)))
    internal_app.handle(Commands::CreateGig.new(title: "3. gig", date: Time.utc(2014, 2, 5, 15, 30)))
    internal_app.handle(Commands::CreateGig.new(title: "2. gig", date: Time.utc(2014, 2, 4, 15, 30)))

    get "/gigs"
  end

  it "responds with 200 Ok" do
    expect(last_status).to eq 200
  end

  it "returns all gigs ordered by date" do
    expect(json_response.size).to eq 3
    expect(json_response.map { |g| g["title"] }).to eq ["1. gig", "2. gig", "3. gig"]
    expect(json_response.first["date"]).to eq "2014-02-03T13:30:00+01:00"
  end
end
