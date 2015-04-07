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
end
