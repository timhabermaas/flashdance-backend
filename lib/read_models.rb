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
        seat_ids: seat_ids
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
        seat_id: seat_id
      }
    end
  end
end
