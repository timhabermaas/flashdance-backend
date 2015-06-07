require "spec_helper"

require "rack/test"

RSpec.describe "orders API endpoint" do
  include Rack::Test::Methods

  before do
    @id_1 = create_seat(gig_id).id
    @id_2 = create_seat(gig_id).id
  end

  let(:gig_id) { create_gig }

  describe "POST /orders" do
    context "valid order" do
      before do
        post "/orders", JSON.generate({email: "peter@heinzelmann.de",
                                       name: "Peter Heinzelmann"})
      end

      it "returns 201 Created" do
        expect(last_status).to eq 201
      end

      it "returns an order id" do
        expect(json_response["orderId"]).to be_a(String)
      end
    end
  end

  describe "PUT /orders/:id/reservations/:seat_id" do
    before do
      post "/orders", JSON.generate({email: "peter@heinzelmann.de",
                                     name: "Peter Heinzelmann"})
      @order_id = json_response["orderId"]
    end

    context "seat is free" do
      before do
        put "/orders/#{@order_id}/reservations/#{@id_1}"
      end

      it "returns 200 Ok" do
        expect(last_status).to eq 200
      end

      it "reserves the seat" do
        get "/gigs/#{gig_id}/reservations"

        expect(json_response.size).to eq 1
        expect(json_response.first["seatId"]).to eq @id_1
      end
    end

    context "seat is already reserved" do
      before do
        put "/orders/#{@order_id}/reservations/#{@id_1}"
        put "/orders/#{@order_id}/reservations/#{@id_1}"
      end

      it "returns 400 Bad Request" do
        expect(last_status).to eq 400
      end
    end
  end

  describe "DELETE /orders/:id/reservations/:seat_id" do
    before do
      post "/orders", JSON.generate({email: "peter@heinzelmann.de",
                                     name: "Peter Heinzelmann"})
      @order_id = json_response["orderId"]
    end

    context "seat reserved by that order" do
      before do
        put "/orders/#{@order_id}/reservations/#{@id_1}"
        delete "/orders/#{@order_id}/reservations/#{@id_1}"
      end

      it "returns 200 Ok" do
        expect(last_status).to eq 200
      end

      it "removes the reservation" do
        get "/gigs/#{gig_id}/reservations"

        expect(json_response).to eq []
      end

      it "returns an empty json response" do
        expect(json_response).to eq({})
      end
    end

    context "seat reserved by another order" do
      before do
        post "/orders", JSON.generate({email: "hans@mustermann.de",
                                       name: "Hans Mustermann"})
        @other_order_id = json_response["orderId"]

        put "/orders/#{@other_order_id}/reservations/#{@id_1}"
        delete "/orders/#{@order_id}/reservations/#{@id_1}"
      end

      it "returns 400 Bad Request" do
        expect(last_status).to eq 400
      end

      it "returns an error response" do
        expect(json_response["errors"].first["message"]).to eq "seat not reserved by order"
      end
    end

    context "seat free" do
      before do
        delete "/orders/#{@order_id}/reservations/#{@id_1}"
      end

      it "returns 400 Bad Request" do
        expect(last_status).to eq 400
      end

      it "returns an error response" do
        expect(json_response["errors"].first["message"]).to eq "seat not reserved by order"
      end
    end
  end

  describe "POST /gigs/:id/orders" do
    context "valid order" do
      before do
        post "/gigs/#{gig_id}/orders", JSON.generate({email: "peter@heinzelmann.de",
                                                      name: "Peter Heinzelmann",
                                                      seatIds: [@id_1, @id_2],
                                                      reducedCount: 1})
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
        expect(json_response.first["reducedCount"]).to eq 1
      end

      it "adds the reservations" do
        get "/gigs/#{gig_id}/reservations"

        expect(json_response.size).to eq 2
        expect(json_response.map { |r| r["seatId"] }).to match_array [@id_1, @id_2]
      end

      it "returns a representation of the order" do
        expect(json_response["name"]).to eq "Peter Heinzelmann"
        expect(json_response["email"]).to eq "peter@heinzelmann.de"
        expect(json_response["seatIds"]).to match_array [@id_1, @id_2]
        expect(json_response["reducedCount"]).to eq 1
        expect(json_response["id"]).to be_a(String)
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
      let(:reduced_count) { 1 }

      before do
        # FIXME having this here is kinda wasteful. It's actually just needed
        #       for the "seat already reserved" case
        post "/gigs/#{gig_id}/orders", JSON.generate({email: email,
                                                      name: name,
                                                      seatIds: [@id_1],
                                                      reducedCount: 0})
        post "/gigs/#{gig_id}/orders", JSON.generate({email: email,
                                                      name: name,
                                                      seatIds: seat_ids,
                                                      reducedCount: reduced_count})
      end

      context "missing email" do
        let(:email) { "" }

        it_behaves_like "missing attribute", "email", "missing attribute `email`"
      end

      context "missing name" do
        let(:name) { nil }

        it_behaves_like "missing attribute", "name", "missing attribute `name`"
      end

      context "missing reducedCount" do
        let(:reduced_count) { nil }

        it_behaves_like "missing attribute", "reducedCount", "missing attribute `reducedCount`"
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

  describe "PUT /orders/:id/pay" do
    context "order doesn't exist" do
      before do
        put "/orders/#{SecureRandom.uuid}/pay"
      end

      it "returns 404 not found" do
        expect(last_status).to eq 404
      end

      it "returns a json response containing 'not found'" do
        expect(json_response["error"]).to eq "not found"
      end
    end

    context "order isn't paid yet" do
      before do
        post "/gigs/#{gig_id}/orders", JSON.generate({email: "peter@heinzelmann.de",
                                                      name: "Peter Heinzelmann",
                                                      seatIds: [@id_1, @id_2],
                                                      reducedCount: 1})
        order_id = json_response["id"]
        put "/orders/#{order_id}/pay"
      end

      it "returns 200 Ok" do
        expect(last_status).to eq 200
      end

      it "sets the order to paid" do
        get "/gigs/#{gig_id}/orders"

        expect(json_response.first["paid"]).to eq true
      end
    end

    context "order is already paid" do
      pending
    end
  end
end
