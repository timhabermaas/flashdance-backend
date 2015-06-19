require "spec_helper"

require "rack/test"

RSpec.describe "orders API endpoint" do
  def create_finished_order
    post "/orders", JSON.generate({email: "peter@heinzelmann.de",
                                   name: "Peter Heinzelmann"})
    order_id = json_response["orderId"]
    put "/orders/#{order_id}/reservations/#{@id_2}"
    put "/orders/#{order_id}/finish", JSON.generate({reducedCount: 1, type: "pickUpBeforehand"})

    order_id
  end

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

    context "order doesn't exist" do
      before do
        put "/orders/#{SecureRandom.uuid}/reservations/#{@id_1}"
      end

      it "returns 404 Not Found" do
        expect(last_status).to eq 404
      end
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

      it "changes the free seat count of a gig" do
        get "/gigs"

        expect(json_response.first["freeSeats"]).to eq 1
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

    context "order doesn't exist" do
      before do
        delete "/orders/#{SecureRandom.uuid}/reservations/#{@id_1}"
      end

      it "returns 404 Not Found" do
        expect(last_status).to eq 404
      end
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

      it "updates the free seat count" do
        get "/gigs"

        expect(json_response.first["freeSeats"]).to eq 2
      end

      context "let's user reserve seat again" do
        before do
          put "/orders/#{@order_id}/reservations/#{@id_1}"
        end

        it "returns 200 Ok" do
          expect(last_status).to eq 200
        end

        it "readds the reservation" do
          get "/gigs/#{gig_id}/reservations"
          expect(json_response.size).to eq 1
        end
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

  describe "PUT /orders/:id/finish" do
    before do
      post "/orders", JSON.generate({email: "hans@mustermann.de",
                                     name: "Hans Mustermann"})

      @order_id = json_response["orderId"]
    end

    context "no seats reserved" do
      before do
        put "/orders/#{@order_id}/reservations/#{@id_1}"
        delete "/orders/#{@order_id}/reservations/#{@id_1}"

        put "/orders/#{@order_id}/finish", JSON.generate({reducedCount: 0, type: "pickUpBeforehand"})
      end

      it "returns 400 Bad Request" do
        expect(last_status).to eq 400
      end
    end

    context "at least one seat reserved" do
      before do
        put "/orders/#{@order_id}/reservations/#{@id_1}"
      end

      context "address set" do
        let(:address) { {street: "foo street 2", postalCode: "52351", city: "Bar"} }

        before do
          put "/orders/#{@order_id}/finish", JSON.generate({reducedCount: 1, address: address})
        end

        it "returns 200 Ok" do
          expect(last_status).to eq 200
        end

        it "adds the order to the /orders endpoint" do
          get "/orders"

          expect(json_response.size).to eq 1
          expect(json_response.first["name"]).to eq "Hans Mustermann"
          expect(json_response.first["email"]).to eq "hans@mustermann.de"
          expect(json_response.first["seatIds"]).to eq [@id_1]
          expect(json_response.first["reducedCount"]).to eq 1
          expect(json_response.first["address"]).to eq({"street" => "foo street 2", "postalCode" => "52351", "city" => "Bar"})
        end
      end

      context "no address set" do
        before do
          put "/orders/#{@order_id}/finish", JSON.generate({reducedCount: 1, type: "pickUpBeforehand"})
        end

        it "returns 200 Ok" do
          expect(last_status).to eq 200
        end

        it "adds the order to the /orders endpoint" do
          get "/orders"

          expect(json_response.size).to eq 1
          expect(json_response.first["name"]).to eq "Hans Mustermann"
          expect(json_response.first["email"]).to eq "hans@mustermann.de"
          expect(json_response.first["seatIds"]).to eq [@id_1]
          expect(json_response.first["reducedCount"]).to eq 1
        end
      end

      context "address set" do
        before do
          put "/orders/#{@order_id}/finish", JSON.generate({reducedCount: 1, address: {street: "Foo Str. 2", postalCode: "12345", city: "Bartown"}})
        end

        it "returns 200 Ok" do
          expect(last_status).to eq 200
        end

        it "adds the order to the /orders endpoint" do
          get "/orders"

          expect(json_response.size).to eq 1
          expect(json_response.first["name"]).to eq "Hans Mustermann"
          expect(json_response.first["email"]).to eq "hans@mustermann.de"
          expect(json_response.first["seatIds"]).to eq [@id_1]
          expect(json_response.first["reducedCount"]).to eq 1
          expect(json_response.first["address"]).to eq({"street" => "Foo Str. 2", "postalCode" => "12345", "city" => "Bartown"})
        end
      end
    end

    context "order doesn't exist" do
      before do
        put "/orders/#{SecureRandom.uuid}/finish", JSON.generate({reducedCount: 1, type: "pickUpBeforehand"})
      end

      it "returns 404 Not Found" do
        expect(last_status).to eq 404
      end
    end
  end

  describe "DELETE /orders/:id" do
    context "order doesn't exist" do
      before do
        delete "/orders/#{SecureRandom.uuid}"
      end

      it "returns 404 Not Found" do
        expect(last_status).to eq 404
      end
    end

    context "order does exist" do
      before do
        order_id = create_finished_order
        delete "/orders/#{order_id}"
      end

      it "returns 200 Ok" do
        expect(last_status).to eq 200
      end

      it "removes the order form /orders" do
        get "/orders"
        expect(json_response).to eq []
      end

      it "removes the reservations from /reservations" do
        get "/gigs/#{gig_id}/reservations"
        expect(json_response).to eq []
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
        post "/orders", JSON.generate({email: "peter@heinzelmann.de",
                                       name: "Peter Heinzelmann"})
        order_id = json_response["orderId"]
        put "/orders/#{order_id}/reservations/#{@id_1}"
        put "/orders/#{order_id}/reservations/#{@id_2}"
        put "/orders/#{order_id}/finish", JSON.generate({reducedCount: 1, type: "pickUpBeforehand"})

        put "/orders/#{order_id}/pay"
      end

      it "returns 200 Ok" do
        expect(last_status).to eq 200
      end

      it "sets the order to paid" do
        get "/orders"

        expect(json_response.first["paid"]).to eq true
      end
    end

    context "order is already paid" do
      before do
        order_id = create_finished_order
        put "/orders/#{order_id}/pay"
        put "/orders/#{order_id}/pay"
      end

      it "returns 400 Bad Request" do
        expect(last_status).to eq 400
      end
    end
  end

  describe "PUT /orders/:id/unpay" do
    context "order doesn't exist" do
      before do
        put "/orders/#{SecureRandom.uuid}/unpay"
      end

      it "returns 404 not found" do
        expect(last_status).to eq 404
      end

      it "returns a json response containing 'not found'" do
        expect(json_response["error"]).to eq "not found"
      end
    end

    context "order is already paid" do
      before do
        post "/orders", JSON.generate({email: "peter@heinzelmann.de",
                                       name: "Peter Heinzelmann"})
        order_id = json_response["orderId"]
        put "/orders/#{order_id}/reservations/#{@id_1}"
        put "/orders/#{order_id}/reservations/#{@id_2}"
        put "/orders/#{order_id}/finish", JSON.generate({reducedCount: 1, type: "pickUpBeforehand"})

        put "/orders/#{order_id}/pay"

        put "/orders/#{order_id}/unpay"
      end

      it "returns 200 Ok" do
        expect(last_status).to eq 200
      end

      it "sets the order to unpaid" do
        get "/orders"

        expect(json_response.first["paid"]).to eq false
      end
    end

    context "order isn't paid yet" do
      before do
        post "/orders", JSON.generate({email: "peter@heinzelmann.de",
                                       name: "Peter Heinzelmann"})
        order_id = json_response["orderId"]
        put "/orders/#{order_id}/reservations/#{@id_2}"
        put "/orders/#{order_id}/finish", JSON.generate({reducedCount: 1, type: "pickUpBeforehand"})

        put "/orders/#{order_id}/unpay"
      end

      it "returns 400 Bad Request" do
        expect(last_status).to eq 400
      end
    end
  end
end
