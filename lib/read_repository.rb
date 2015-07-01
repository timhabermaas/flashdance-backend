class ReadRepository
  attr_reader :orders,
              :reservations

  def initialize(connection)
    @connection = connection
    reset!
  end

  def reset!
    @orders = {}
    @reservations = Hash.new { |h, k| h[k] = [] }
  end

  def full_seats_count(gig_id)
    @reservations[gig_id].size
  end

  def update!(event)
    case event
    when Events::OrderStarted
      @orders[event.aggregate_id] = ReadModels::Order.new(event.aggregate_id, event.name, event.email, [], false, 0, event.created_at)
    when Events::OrderNumberSet
      @orders[event.aggregate_id].number = event.number
    when Events::SeatAddedToOrder
      @orders[event.aggregate_id].add_seat(event.seat_id)
    when Events::SeatRemovedFromOrder
      @orders[event.aggregate_id].remove_seat(event.seat_id)
    when Events::ReducedTicketsSet
      @orders[event.aggregate_id].reduced_count = event.reduced_count
    when Events::OrderFinished
      @orders[event.aggregate_id].finish!
    when Events::OrderPaid
      @orders[event.aggregate_id].pay!
    when Events::OrderUnpaid
      @orders[event.aggregate_id].unpay!
    when Events::OrderCanceled
      @orders.delete(event.aggregate_id)
    when Events::PickUpAtSchoolPicked
      @orders[event.aggregate_id].pick_up_beforehand = true
    when Events::AddressAdded
      @orders[event.aggregate_id].address = ReadModels::Address.new(event.street, event.postal_code, event.city)
    when Events::SeatReserved
      seat_id = event.aggregate_id
      gig_id = get_gig_id_from_seat(seat_id)
      @reservations[gig_id] << ReadModels::Reservation.new(seat_id)
    when Events::SeatFreed
      seat_id = event.aggregate_id
      gig_id = get_gig_id_from_seat(seat_id)
      @reservations[gig_id].delete_if { |r| r.seat_id == seat_id }
    end
  end

  private
    def get_gig_id_from_seat(seat_id)
      @connection[:rows].join(:seats, row_id: :id).where(Sequel.qualify(:seats, :id) => seat_id).first[:gig_id]
    end
end
