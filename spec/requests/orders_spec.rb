require "spec_helper"

require "rack/test"

RSpec.describe "/gigs/:id/orders" do
  include Rack::Test::Methods

  describe "POST /gigs/:id/orders" do
    before do
      @id_1 = create_seat.id
      @id_2 = create_seat.id
    end

    let(:gig_id) { create_gig }

    context "valid order" do
      before do
        post "/gigs/#{gig_id}/orders", JSON.generate({email: "peter@heinzelmann.de",
                                                      name: "Peter Heinzelmann",
                                                      seatIds: [@id_1, @id_2]})
      end

      it "returns 201 Created" do
        expect(last_status).to eq 201
      end

      it "adds the order" do
        get "/gigs/#{gig_id}/orders"

        expect(json_response.size).to eq 1
        expect(json_response.first["name"]).to eq "Peter Heinzelmann"
        expect(json_response.first["email"]).to eq "peter@heinzelmann.de"
        expect(json_response.first["seatIds"]).to eq [@id_1, @id_2]
      end

      it "adds the reservations" do
        get "/gigs/#{gig_id}/reservations"

        expect(json_response.size).to eq 2
        expect(json_response.map { |r| r["seatId"] }).to match_array [@id_1, @id_2]
      end
    end

    context "invalid order" do
      shared_examples_for "missing attribute" do |attribute, error_message|
        it "returns 422 Unprocessable Entity" do
          expect(last_status).to eq 422
        end

        it "has a errors json response present" do
          expect(json_response.key?("errors")).to eq true
          expect(json_response["errors"].first["message"]).to eq error_message
          expect(json_response["errors"].first["attribute"]).to eq attribute
          expect(json_response["errors"].first["code"]).to eq "missing_field"
        end
      end

      let(:email) { "foo@bar.com" }
      let(:name) { "Max Mustermann" }
      let(:seat_ids) { [@id_2] }

      before do
        # FIXME having this here is kinda wasteful. It's actually just needed
        #       for the "seat already reserved" case
        post "/gigs/#{gig_id}/orders", JSON.generate({email: email,
                                                      name: name,
                                                      seatIds: [@id_1]})
        post "/gigs/#{gig_id}/orders", JSON.generate({email: email,
                                                      name: name,
                                                      seatIds: seat_ids})
      end

      context "missing email" do
        let(:email) { "" }

        it_behaves_like "missing attribute", "email", "missing attribute `email`"
      end

      context "missing name" do
        let(:name) { nil }

        it_behaves_like "missing attribute", "name", "missing attribute `name`"
      end

      context "empty seatIds" do
        let(:seat_ids) { nil }

        it_behaves_like "missing attribute", "seatIds", "missing attribute `seatIds`"
      end

      context "empty seats" do
        let(:seat_ids) { [] }

        it_behaves_like "missing attribute", "seatIds", "missing attribute `seatIds`"
      end

      context "seats already reserved" do
        let(:seat_ids) { [@id_1] }

        # TODO correct status?
        it "returns 422 Unprocessable Entity" do
          expect(last_status).to eq 422
        end

        it "returns an error response containing the exact error" do
          expect(json_response["errors"].first["message"]).to eq "Some seats are already reserved"
          expect(json_response["errors"].first["attribute"]).to eq "seatIds"
          expect(json_response["errors"].first["code"]).to eq "already_exists"
        end
      end
    end
  end
end
