require "command_handlers"
require "query_handlers"
require "commands"
require "queries"
require "events"
require "aggregates"
require "read_models"

require "sequel"
require "securerandom"


class App
  class DomainError < StandardError; end
  class RecordNotFound < StandardError; end
  class SeatsReserved < DomainError; end
  class SeatAlreadyReserved < DomainError; end
  class SeatNotReserved < DomainError; end

  def initialize(database_url, logging=true)
    loggers = logging ? [Logger.new($stdout)] : []
    @connection = Sequel.connect(database_url, loggers: loggers)
    Sequel.application_timezone = "Berlin"
    Sequel.database_timezone = "UTC"
    Sequel::Model.plugin :timestamps
  end

  # FIXME Remove this method by not using Sequel models.
  def load_models!
    require "models"
  end

  def answer(query)
    {
      Queries::ListFinishedOrders => answerer { |q|
        fetch_events.reduce({}, &self.method(:update_orders)).values
      },
      Queries::ListReservationsForGig => answerer { |q|
        fetch_events.reduce(Hash.new { |h, key| h[key] = []}, &self.method(:update_reservations))[q.gig_id]
      },
      Queries::GetFreeSeats => answerer { |q|
        reserved_seats = fetch_events_for(aggregate_id: q.gig_id).reduce(Hash.new { |h, key| h[key] = 0 }, &self.method(:update_reserved_seats_count))[q.gig_id]
        all_seats = DBModels::Seat.join(:rows, id: :row_id).where(gig_id: q.gig_id).where(usable: true).count
        all_seats - reserved_seats
      },
      Queries::ListSeats => answerer { |q|
        @connection[:seats].join(:rows, id: :row_id).select(Sequel.qualify(:seats, :id), :x, Sequel.qualify(:seats, :number), :usable, Sequel.qualify(:rows, :number).as(:row_number)).where(Sequel.qualify(:rows, :gig_id) => q.gig_id).all
      },
      Queries::ListRows => answerer { |q|
        @connection[:rows].where(gig_id: q.gig_id).all
      },
    }.fetch(query.class).answer(query)
  end

  def handle(command)
    {
      Commands::CreateRow => handler { |c| DBModels::Row.create(y: c.y, number: c.number, gig_id: c.gig_id) },
      Commands::CreateSeat => handler { |c| DBModels::Seat.create(x: c.x, number: c.number, usable: c.usable, row_id: c.row_id) },
      Commands::CreateGig => handler { |c| DBModels::Gig.create(title: c.title, date: c.date) },
      Commands::SubmitOrder => handler do |c|
        reservations = fetch_events.reduce(Hash.new { |h, key| h[key] = []}, &self.method(:update_reservations))[c.gig_id]
        if reservations.map(&:seat_id) & c.seat_ids != []
          raise SeatsReserved.new(reservations.map(&:seat_id) & c.seat_ids)
        end
        events = []
        order_id = SecureRandom.uuid
        events << Events::OrderPlaced.new(aggregate_id: order_id, gig_id: c.gig_id, seat_ids: c.seat_ids, name: c.name, email: c.email, reduced_count: c.reduced_count)
        events << Events::SeatsReserved.new(aggregate_id: c.gig_id, order_id: order_id, seat_ids: c.seat_ids)
        persist_events(events)
        return order_id
      end,
      Commands::PayOrder => handler do |c|
        events = fetch_events_for(aggregate_id: c.order_id)
        if events.empty?
          raise ArgumentError
        else
          persist_event(Events::OrderPaid.new(aggregate_id: c.order_id))
        end
      end,
      Commands::StartOrder => handler do |c|
        order_id = SecureRandom.uuid
        persist_event(Events::OrderStarted.new(aggregate_id: order_id, name: c.name, email: c.email))
        order_id
      end,
      Commands::ReserveSeat => handler do |c|
        gig_id = get_gig_id_from_seat(c.seat_id)
        gig = Aggregates::Gig.new(gig_id, fetch_events_for(aggregate_id: gig_id))

        order_events = fetch_events_for(aggregate_id: c.order_id)
        raise RecordNotFound.new if order_events.empty?
        order = Aggregates::Order.new(order_events)

        persist_events order.reserve_seat!(gig, c.seat_id)
      end,
      Commands::FreeSeat => handler do |c|
        gig_id = get_gig_id_from_seat(c.seat_id)
        reservations = fetch_events.reduce(Hash.new { |h, key| h[key] = Set.new}, &self.method(:update_reserved_seats_for_order))[c.order_id]
        if fetch_events_for(aggregate_id: c.order_id).empty?
          raise RecordNotFound.new
        elsif reservations.include?(c.seat_id)
          events = [
            Events::SeatRemovedFromOrder.new(aggregate_id: c.order_id, seat_id: c.seat_id),
            Events::SeatFreed.new(aggregate_id: gig_id, seat_id: c.seat_id)
          ]
          persist_events(events)
        else
          raise SeatNotReserved.new(c.seat_id)
        end
      end,
      Commands::FinishOrder => handler do |c|
        order_events = fetch_events_for(aggregate_id: c.order_id)
        order = fetch_domain(klass: Aggregates::Order, aggregate_id: c.order_id)
        events = order.finish!(c.reduced_count)
        persist_events(events)
      end
    }.fetch(command.class).handle(command)
  end

  def clean_db!
    @connection[:seats].delete
    @connection[:rows].delete
    @connection[:gigs].delete
    @connection[:events].delete
  end

  def migrate!
    Sequel.extension :migration, :core_extensions
    Sequel::Migrator.run(connect, File.dirname(__FILE__) + '/../migrations')
  end

  private
    def handler(&block)
      CommandHandlers::GenericHandler.new(&block)
    end

    def answerer(&block)
      QueryHandlers::GenericHandler.new(&block)
    end

    def update_reservations(reservations, event)
      case event
      when Events::SeatReserved
        reservations[event.aggregate_id] += [ReadModels::Reservation.new(event.seat_id)]
        reservations
      when Events::SeatFreed
        reservations[event.aggregate_id].delete_if { |r| r.seat_id == event.seat_id }
        reservations
      when Events::SeatsReserved
        reservations[event.aggregate_id] += event.seat_ids.map { |s| ReadModels::Reservation.new(s) }
        reservations
      else
        reservations
      end
    end

    def update_reserved_seats(reservations, event)
      case event
      when Events::SeatReserved
        reservations[event.aggregate_id] << event.seat_id
        reservations
      when Events::SeatFreed
        reservations[event.aggregate_id].delete_if { |e| e == event.seat_id }
        reservations
      else
        reservations
      end
    end

    def update_reserved_seats_for_order(reservations, event)
      case event
      when Events::SeatAddedToOrder
        reservations[event.aggregate_id] << event.seat_id
        reservations
      else
        reservations
      end
    end

    def update_reserved_seats_count(seats, event)
      case event
      when Events::SeatReserved
        seats[event.aggregate_id] += 1
        seats
      when Events::SeatsReserved
        seats[event.aggregate_id] += event.seat_ids.size
        seats
      else
        seats
      end
    end

    def update_orders(orders, event)
      case event
      when Events::OrderStarted
        orders[event.aggregate_id] = ReadModels::Order.new(event.aggregate_id, event.name, event.email, [], false, 0, event.created_at)
        orders
      when Events::SeatAddedToOrder
        order = orders[event.aggregate_id]
        order.add_seat(event.seat_id)
        orders
      when Events::SeatRemovedFromOrder
        order = orders[event.aggregate_id]
        order.remove_seat(event.seat_id)
        orders
      when Events::ReducedTicketsSet
        order = orders[event.aggregate_id]
        order.reduced_count = event.reduced_count
        orders
      when Events::OrderPaid
        order = orders[event.aggregate_id]
        order.pay!
        orders
      else
        orders
      end
    end

    def fetch_events
      DBModels::Event.order(:global_version).map(&method(:deserialize_event))
    end

    def fetch_events_for(aggregate_id:)
      DBModels::Event.where(aggregate_id: aggregate_id).order(:global_version).map(&method(:deserialize_event))
    end

    def persist_event(event)
      DBModels::Event.create(aggregate_id: event.aggregate_id,
                             type: event.class.to_s,
                             user_id: nil,
                             body: JSON.generate(event.serialize))
    end

    def persist_events(events)
      @connection.transaction do
        events.each { |e| persist_event(e) }
      end
    end

    def deserialize_event(event_hash)
      klass = Object.const_get(event_hash[:type])
      body = JSON.parse(event_hash[:body])
      klass.new(body.merge(aggregate_id: event_hash[:aggregate_id], created_at: event_hash[:created_at]))
    end

    def fetch_domain(klass:, aggregate_id:)
      events = fetch_events_for(aggregate_id: aggregate_id)
      klass.new(events)
    end

    def get_gig_id_from_seat(seat_id)
      @connection[:rows].join(:seats, row_id: :id).where(Sequel.qualify(:seats, :id) => seat_id).first[:gig_id]
    end
end
