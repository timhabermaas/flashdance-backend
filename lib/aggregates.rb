require "events"
require "set"

module Aggregates
  class Gig
    class SeatAlreadyReserved < StandardError; end

    def initialize(id, events)
      @id = id
      @reserved_seats = Set.new
      events.each { |e| apply(e) }
    end

    def apply(event)
      case event
      when Events::SeatReserved
        @reserved_seats << event.seat_id
      when Events::SeatFreed
        @reserved_seats.delete(event.seat_id)
      end
    end

    def seat_reserved?(seat_id)
      @reserved_seats.include?(seat_id)
    end

    def reserve_seat!(seat_id)
      if seat_reserved?(seat_id)
        raise SeatAlreadyReserved.new(seat_id)
      end

      [Events::SeatReserved.new(aggregate_id: @id, seat_id: seat_id)]
    end
  end

  class Order
    class CantFinishOrder < StandardError; end

    def initialize(events)
      @reserved_seats = Set.new
      @order_id = nil
      events.each { |e| apply(e) }
    end

    def apply(event)
      case event
      when Events::SeatAddedToOrder
        @reserved_seats << event.seat_id
      when Events::SeatRemovedFromOrder
        @reserved_seats.delete(event.seat_id)
      when Events::OrderStarted
        @order_id = event.aggregate_id
      end
    end
    private :apply

    def finish!(reduced_count)
      raise CantFinishOrder.new if @reserved_seats.empty?
      raise CantFinishOrder.new if @reserved_seats.size - reduced_count < 0

      [
        Events::ReducedTicketsSet.new(aggregate_id: @order_id, reduced_count: reduced_count),
        Events::OrderFinished.new(aggregate_id: @order_id)
      ]
    end

    def reserve_seat!(gig, seat_id)
      gig.reserve_seat!(seat_id) + [Events::SeatAddedToOrder.new(aggregate_id: @order_id, seat_id: seat_id)]
    end
  end
end
