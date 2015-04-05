module DBModels
  class Gig < Sequel::Model
  end

  class Seat < Sequel::Model
    many_to_one :row

    def unusable!
      set(usable: false)
    end

    def serialize
      {x: x, number: number, row: row.number, id: id, usable: usable}
    end
  end

  class Row < Sequel::Model
    one_to_many :seats

    def serialize
      {y: y, number: number}
    end
  end
end
