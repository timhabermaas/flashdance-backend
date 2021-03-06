require "spec_helper"
require "rack/test"

RSpec.describe "/gigs/:id/seats" do
  include Rack::Test::Methods

  context "gig exists" do
    before do
      gig_id = create_gig
      second_gig = create_gig

      row = internal_app.handle(Commands::CreateRow.new(y: 1, number: 2, gig_id: gig_id))

      internal_app.handle(Commands::CreateSeat.new(x: 1, number: 3, row_id: row.id, usable: false))
      internal_app.handle(Commands::CreateSeat.new(x: 2, number: 4, row_id: row.id))

      row = internal_app.handle(Commands::CreateRow.new(y: 1, number: 2, gig_id: second_gig))
      internal_app.handle(Commands::CreateSeat.new(x: 1, number: 2, row_id: row.id))

      get "/gigs/#{gig_id}/seats"
    end

    it "responds with 200 Ok" do
      expect(last_status).to eq 200
    end

    it "returns the seats" do
      expect(json_response["seats"].size).to eq 2
      expect(json_response["seats"].first["number"]).to eq 3
      expect(json_response["seats"].first["x"]).to eq 1
      expect(json_response["seats"].first["row"]).to eq 2
      expect(json_response["seats"].first["usable"]).to eq false
      expect(json_response["seats"].last["number"]).to eq 4
      expect(json_response["seats"].last["x"]).to eq 2
      expect(json_response["seats"].last["row"]).to eq 2
      expect(json_response["seats"].last["usable"]).to eq true
    end

    it "returns the rows" do
      expect(json_response["rows"].size).to eq 1
      expect(json_response["rows"].first["y"]).to eq 1
      expect(json_response["rows"].first["number"]).to eq 2
    end
  end

  context "gig doesn't exist" do
    before do
      get "/gigs/#{SecureRandom.uuid}/seats"
    end

    it "responds with 404 Not Found" do
      expect(last_status).to eq 404
      expect(json_response["error"]).to eq "not found"
    end
  end
end
