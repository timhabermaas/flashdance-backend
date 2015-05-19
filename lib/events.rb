require "virtus"

module Events
  class AbstractEvent
    include Virtus.model(strict: true)

    attribute :aggregate_id, String

    def serialize
      {}
    end
  end

  class AvailableSeatsDetermined < AbstractEvent
    attribute :seat_ids, Array[String]

    def serialize
      {seat_ids: seat_ids}
    end
  end

  class OrderPlaced < AbstractEvent
    attribute :name, String
    attribute :email, String
    attribute :seat_ids, Array[String]
    attribute :gig_id, String
    attribute :reduced_count, Integer

    def serialize
      {
        name: name,
        email: email,
        seat_ids: seat_ids,
        gig_id: gig_id,
        reduced_count: reduced_count
      }
    end
  end

  class SeatsReserved < AbstractEvent
    attribute :seat_ids, Array[String]
    attribute :order_id, String

    def serialize
      {seat_ids: seat_ids, order_id: order_id}
    end
  end

  class OrderPaid < AbstractEvent
    def serialize
      {}
    end
  end

  class OrderStarted < AbstractEvent
    def serialize
      {}
    end
  end
end
