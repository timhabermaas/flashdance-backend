module Queries
  class AbstractQuery
    include Virtus.model(strict: true)
  end

  class ListOrdersForGig < AbstractQuery
    attribute :gig_id, String
  end
end
