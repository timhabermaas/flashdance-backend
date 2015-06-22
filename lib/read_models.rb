module ReadModels
  class Address
    def initialize(street, postal_code, city)
      @street = street
      @postal_code = postal_code
      @city = city
    end

    attr_reader :city, :street, :postal_code

    def serialize
      {
        city: city,
        street: street,
        postalCode: postal_code
      }
    end
  end

  class Order
    attr_reader :id, :name, :email, :seat_ids, :paid, :created_at
    attr_accessor :reduced_count
    attr_accessor :number
    attr_accessor :address
    attr_accessor :pick_up_beforehand

    def initialize(id, name, email, seat_ids, paid, reduced_count, created_at)
      @id = id
      @name = name
      @email = email
      @seat_ids = seat_ids
      @paid = paid
      @reduced_count = reduced_count
      @created_at = created_at
      @finished = false
    end

    def finish!
      @finished = true
    end

    def finished?
      @finished
    end

    def add_seat(seat_id)
      @seat_ids << seat_id
    end

    def pick_up_beforehand?
      !!@pick_up_beforehand
    end

    def delivery?
      !!address
    end

    def number
      @number || -1
    end

    def total_cost
      (@seat_ids.size - @reduced_count) * 1600 + @reduced_count * 1200 + delivery_cost
    end

    def remove_seat(seat_id)
      @seat_ids.delete_if { |s| s == seat_id }
    end

    def serialize
      {
        id: id,
        name: name,
        email: email,
        seatIds: seat_ids,
        paid: paid,
        number: number,
        reducedCount: reduced_count,
        createdAt: created_at.iso8601,
        address: (address ? address.serialize : nil)
      }
    end

    def pay!
      @paid = true
    end

    def unpay!
      @paid = false
    end

    private
      def delivery_cost
        @address ? 300 : 0
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
      {id: id, title: title, date: date.iso8601, freeSeats: @free_seats}
    end
  end
end
