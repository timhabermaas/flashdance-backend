module ReadModels
  class Order
    attr_reader :id, :name, :email, :seat_ids, :paid, :created_at
    attr_accessor :reduced_count

    def initialize(id, name, email, seat_ids, paid, reduced_count, created_at)
      @id = id
      @name = name
      @email = email
      @seat_ids = seat_ids
      @paid = paid
      @reduced_count = reduced_count
      @created_at = created_at
    end

    def add_seat(seat_id)
      @seat_ids << seat_id
    end

    def remove_seat(seat_id)
      @seat_ids.delete_if { |s| s == seat_id }
    end

    def serialize
      {
        name: name,
        email: email,
        seatIds: seat_ids,
        paid: paid,
        reducedCount: reduced_count,
        created_at: created_at.iso8601
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
