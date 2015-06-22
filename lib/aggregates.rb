require "events"
require "result"
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
    SeatAlreadyReserved = Struct.new(:seat_id)

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


    def free_seat!(seat_id)
      if seat_reserved?(seat_id)
        Ok([Events::SeatFreed.new(aggregate_id: @id, seat_id: seat_id)])
      else
        Ok([])
      end
    end

    def reserve_seat!(seat_id)
      if seat_reserved?(seat_id)
        return Error(SeatAlreadyReserved.new(seat_id))
      end

      Ok([Events::SeatReserved.new(aggregate_id: @id, seat_id: seat_id)])
    end

    private
      def seat_reserved?(seat_id)
        @reserved_seats.include?(seat_id)
      end
  end

  class Order < DomainModel
    class CantFinishOrder; end
    class OrderAlreadyPaid; end
    class OrderNotYetPaid; end

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
      return Error(CantFinishOrder.new) if @reserved_seats.empty?
      return Error(CantFinishOrder.new) if @reserved_seats.size - reduced_count < 0

      Ok([
        Events::ReducedTicketsSet.new(aggregate_id: @order_id, reduced_count: reduced_count),
        (if type == "pickUpBeforehand" then Events::PickUpAtSchoolPicked.new(aggregate_id: @order_id) else Events::PickUpBeforeGigPicked.new(aggregate_id: @order_id) end),
        Events::OrderFinished.new(aggregate_id: @order_id)
      ])
    end

    def finish_and_deliver!(reduced_count, street, postal_code, city)
      return Error(CantFinishOrder.new) if @reserved_seats.empty?
      return Error(CantFinishOrder.new) if @reserved_seats.size - reduced_count < 0

      Ok([
        Events::ReducedTicketsSet.new(aggregate_id: @order_id, reduced_count: reduced_count),
        Events::AddressAdded.new(aggregate_id: @order_id, street: street, postal_code: postal_code, city: city),
        Events::OrderFinished.new(aggregate_id: @order_id)
      ])
    end

    def pay!
      return Error(OrderAlreadyPaid.new) if @paid
      Ok([Events::OrderPaid.new(aggregate_id: @order_id)])
    end

    def unpay!
      return Error(OrderNotYetPaid.new) if !@paid
      Ok([Events::OrderUnpaid.new(aggregate_id: @order_id)])
    end

    def cancel!(gigs)
      return Error(nil) if @canceled
      events = Ok([Events::OrderCanceled.new(aggregate_id: @order_id)])
      @reserved_seats.each do |seat_id|
        events = events.and_then do |events|
          gigs[seat_id].free_seat!(seat_id).and_then do |e|
            Ok(events + e)
          end
        end
      end
      events
    end

    def reserve_seat!(gig, seat_id)
      gig.reserve_seat!(seat_id).and_then do |events|
        Ok(events + [Events::SeatAddedToOrder.new(aggregate_id: @order_id, seat_id: seat_id)])
      end
    end
  end
end
