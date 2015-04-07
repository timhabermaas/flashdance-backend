require "spec_helper"

require "rack/test"

RSpec.describe "/gigs/:id/orders" do
  include Rack::Test::Methods

  describe "POST /gigs/:id/orders" do
    let(:gig_id) { create_gig }

    before do
      @id_1 = create_seat.id
      @id_2 = create_seat.id
      post "/gigs/#{gig_id}/orders", JSON.generate({email: "peter@heinzelmann.de",
                                                    name: "Peter Heinzelmann",
                                                    seat_ids: [@id_1, @id_2]})
    end

    it "returns 201 Created" do
      expect(last_status).to eq 201
    end

    it "adds the order" do
      get "/gigs/#{gig_id}/orders"

      expect(json_response.size).to eq 1
      expect(json_response.first["name"]).to eq "Peter Heinzelmann"
      expect(json_response.first["email"]).to eq "peter@heinzelmann.de"
      expect(json_response.first["seat_ids"]).to eq [@id_1, @id_2]
    end
  end
end
