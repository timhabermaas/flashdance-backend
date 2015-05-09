module ReadModels
  class Order
    attr_reader :id, :name, :email, :seat_ids, :paid, :reduced_count

    def initialize(id, name, email, seat_ids, paid, reduced_count)
      @id = id
      @name = name
      @email = email
      @seat_ids = seat_ids
      @paid = paid
      @reduced_count = reduced_count
    end

    def serialize
      {
        name: name,
        email: email,
        seatIds: seat_ids,
        paid: paid,
        reducedCount: reduced_count
      }
    end

    def pay!
      @paid = true
    end
  end

  class Reservation
    attr_reader :seat_id

    def initialize(seat_id)
      @seat_id = seat_id
    end

    def serialize
      {
        seatId: seat_id
      }
    end
  end

  class Gig < SimpleDelegator
    attr_reader :free_seats

    def initialize(gig, free_seats)
      super(gig)
      @free_seats = free_seats
    end

    def serialize
      __getobj__.serialize.merge(freeSeats: @free_seats)
    end
  end
end
