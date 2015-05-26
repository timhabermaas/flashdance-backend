require "virtus"

module Commands
  class AbstractCommand
    include Virtus.model(strict: true)
  end

  class CreateRow < AbstractCommand
    attribute :y, Integer
    attribute :number, Integer
    attribute :gig_id, String
  end

  class CreateSeat < AbstractCommand
    attribute :x, Integer
    attribute :number, Integer
    attribute :row_id, String # FIXME This is actually a UUID
    attribute :usable, Boolean, default: true
  end

  class CreateGig < AbstractCommand
    attribute :title, String
    attribute :date, DateTime
  end

  class SubmitOrder < AbstractCommand
    attribute :gig_id, String
    attribute :name, String
    attribute :email, String
    attribute :seat_ids, Array[String]
    attribute :reduced_count, Integer
  end

  class PayOrder < AbstractCommand
    attribute :order_id, String
  end

  class StartOrder < AbstractCommand
    attribute :name, String
    attribute :email, String
  end
end
