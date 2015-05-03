module ReadModels
  class Order
    attr_reader :name, :email, :seat_ids

    def initialize(name, email, seat_ids)
      @name = name
      @email = email
      @seat_ids = seat_ids
    end

    def serialize
      {
        name: name,
        email: email,
        seatIds: seat_ids
      }
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
