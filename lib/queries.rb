module Queries
  class AbstractQuery
    include Virtus.model(strict: true)
  end

  class ListFinishedOrders < AbstractQuery
  end

  class ListReservationsForGig < AbstractQuery
    attribute :gig_id, String
  end

  class GetFreeSeats < AbstractQuery
    attribute :gig_id, String
  end

  class ListSeats < AbstractQuery
    attribute :gig_id, String
  end

  class ListRows < AbstractQuery
    attribute :gig_id, String
  end
end
