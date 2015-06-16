require "virtus"

module Events
  class AbstractEvent
    include Virtus.model(strict: true)

    attribute :aggregate_id, String
    attribute :created_at, DateTime, default: DateTime.now

    def serialize
      {}
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

  class OrderPaid < AbstractEvent
    def serialize
      {}
    end
  end

  class OrderUnpaid < AbstractEvent
    def serialize
      {}
    end
  end

  class AddressAdded < AbstractEvent
    attribute :street, String
    attribute :postal_code, String
    attribute :city, String

    def serialize
      {city: city, postal_code: postal_code, street: street}
    end
  end

  class PickUpAtSchoolPicked < AbstractEvent
  end

  class PickUpBeforeGigPicked < AbstractEvent
  end

  class DeliveryPicked < AbstractEvent
  end

  class OrderStarted < AbstractEvent
    attribute :name, String
    attribute :email, String

    def serialize
      {name: name, email: email}
    end
  end

  class OrderNumberSet < AbstractEvent
    attribute :number, Integer

    def serialize
      {number: number}
    end
  end

  class SeatReserved < AbstractEvent
    attribute :seat_id, String

    def serialize
      {seat_id: seat_id}
    end
  end

  class SeatAddedToOrder < AbstractEvent
    attribute :seat_id, String

    def serialize
      {seat_id: seat_id}
    end
  end

  class SeatRemovedFromOrder < AbstractEvent
    attribute :seat_id, String

    def serialize
      {seat_id: seat_id}
    end
  end

  class SeatFreed < AbstractEvent
    attribute :seat_id, String

    def serialize
      {seat_id: seat_id}
    end
  end

  class ReducedTicketsSet < AbstractEvent
    attribute :reduced_count, Integer

    def serialize
      {reduced_count: reduced_count}
    end
  end

  class OrderFinished < AbstractEvent
  end

  class OrderCanceled < AbstractEvent
  end
end
