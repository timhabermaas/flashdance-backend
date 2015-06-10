require "events"
require "set"

module Aggregates
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

    def finish!(reduced_count)
      raise CantFinishOrder.new if @reserved_seats.empty?
      raise CantFinishOrder.new if @reserved_seats.size - reduced_count < 0

      [
        Events::ReducedTicketsSet.new(aggregate_id: @order_id, reduced_count: reduced_count),
        Events::OrderFinished.new(aggregate_id: @order_id)
      ]
    end
  end
end
