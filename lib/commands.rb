require 'virtus'

module Commands
  class AbstractCommand
    include Virtus.model(strict: true)
  end

  class CreateRow < AbstractCommand
    attribute :y, Integer
    attribute :number, Integer
  end

  class CreateSeat < AbstractCommand
    attribute :x, Integer
    attribute :number, Integer
    attribute :row_id, Integer
    attribute :usable, Boolean, default: true
  end

  class CreateGig < AbstractCommand
    attribute :title, String
    attribute :date, DateTime
  end
end
