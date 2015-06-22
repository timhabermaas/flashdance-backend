module DBModels
  class Gig < Sequel::Model
  end

  class Seat < Sequel::Model
    many_to_one :row

    def unusable!
      set(usable: false)
    end
  end

  class Row < Sequel::Model
    one_to_many :seats
  end

  class Event < Sequel::Model
  end
end
