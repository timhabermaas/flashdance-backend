require "events"
require "set"

module Aggregates
  class DomainModel
    def initialize(events)
      events.each { |e| apply(e) }
    end

    def apply
      raise NotImplementedError
    end
  end

  class Gig < DomainModel
    class SeatAlreadyReserved < StandardError; end

    def initialize(id, events)
      @id = id
      @reserved_seats = Set.new
      super(events)
    end

    def apply(event)
      case event
      when Events::SeatReserved
        @reserved_seats << event.seat_id
      when Events::SeatFreed
        @reserved_seats.delete(event.seat_id)
      end
    end
    private :apply

    def seat_reserved?(seat_id)
      @reserved_seats.include?(seat_id)
    end

    def free_seat!(seat_id)
      if seat_reserved?(seat_id)
        [Events::SeatFreed.new(aggregate_id: @id, seat_id: seat_id)]
      else
        []
      end
    end

    def reserve_seat!(seat_id)
      if seat_reserved?(seat_id)
        raise SeatAlreadyReserved.new(seat_id)
      end

      [Events::SeatReserved.new(aggregate_id: @id, seat_id: seat_id)]
    end
  end

  class Order < DomainModel
    class CantFinishOrder < StandardError; end
    class OrderAlreadyPaid < StandardError; end
    class OrderNotYetPaid < StandardError; end

    def initialize(events)
      @reserved_seats = Set.new
      @order_id = nil
      super(events)
    end

    def apply(event)
      case event
      when Events::SeatAddedToOrder
        @reserved_seats << event.seat_id
      when Events::SeatRemovedFromOrder
        @reserved_seats.delete(event.seat_id)
      when Events::OrderStarted
        @order_id = event.aggregate_id
      when Events::OrderPaid
        @paid = true
      when Events::OrderUnpaid
        @paid = false
      when Events::OrderCanceled
        @canceled = true
      end
    end
    private :apply

    def finish!(reduced_count, type)
      raise CantFinishOrder.new if @reserved_seats.empty?
      raise CantFinishOrder.new if @reserved_seats.size - reduced_count < 0

      [
        Events::ReducedTicketsSet.new(aggregate_id: @order_id, reduced_count: reduced_count),
        (if type == "pickUpBeforehand" then Events::PickUpAtSchoolPicked.new(aggregate_id: @order_id) else Events::PickUpBeforeGigPicked.new(aggregate_id: @order_id) end),
        Events::OrderFinished.new(aggregate_id: @order_id)
      ]
    end

    def finish_and_deliver!(reduced_count, street, postal_code, city)
      raise CantFinishOrder.new if @reserved_seats.empty?
      raise CantFinishOrder.new if @reserved_seats.size - reduced_count < 0

      [
        Events::ReducedTicketsSet.new(aggregate_id: @order_id, reduced_count: reduced_count),
        Events::AddressAdded.new(aggregate_id: @order_id, street: street, postal_code: postal_code, city: city),
        Events::OrderFinished.new(aggregate_id: @order_id)
      ]
    end

    def pay!
      raise OrderAlreadyPaid if @paid
      [Events::OrderPaid.new(aggregate_id: @order_id)]
    end

    def unpay!
      raise OrderNotYetPaid if !@paid
      [Events::OrderUnpaid.new(aggregate_id: @order_id)]
    end

    def cancel!(gigs)
      return if @canceled
      events = [Events::OrderCanceled.new(aggregate_id: @order_id)]
      @reserved_seats.each do |seat_id|
        events += gigs[seat_id].free_seat!(seat_id)
      end
      events
    end

    def reserve_seat!(gig, seat_id)
      gig.reserve_seat!(seat_id) + [Events::SeatAddedToOrder.new(aggregate_id: @order_id, seat_id: seat_id)]
    end
  end
end
