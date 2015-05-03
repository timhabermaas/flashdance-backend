require "command_handlers"
require "query_handlers"
require "commands"
require "queries"
require "events"
require "read_models"

require "sequel"
require "securerandom"


class App
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
      Queries::ListOrdersForGig => answerer { |q|
        orders = fetch_events.reduce(Hash.new { |h, key| h[key] = []}, &self.method(:update_orders))
        orders[q.gig_id]
      },
      Queries::ListReservationsForGig => answerer { |q|
        fetch_events.reduce(Hash.new { |h, key| h[key] = []}, &self.method(:update_reservations))[q.gig_id]
      },
      Queries::GetFreeSeats => answerer { |q|
        reserved_seats = fetch_events.reduce(Hash.new { |h, key| h[key] = 0 }, &self.method(:update_reserved_seats))[q.gig_id]
        all_seats = DBModels::Seat.where(usable: true).count
        all_seats - reserved_seats
      }
    }.fetch(query.class).answer(query)
  end

  def handle(command)
    {
      Commands::CreateRow => handler { |c| DBModels::Row.create(y: c.y, number: c.number) },
      Commands::CreateSeat => handler { |c| DBModels::Seat.create(x: c.x, number: c.number, usable: c.usable, row_id: c.row_id) },
      Commands::CreateGig => handler { |c| DBModels::Gig.create(title: c.title, date: c.date) },
      Commands::SubmitOrder => handler do |c|
        events = []
        order_id = SecureRandom.uuid
        events << Events::OrderPlaced.new(aggregate_id: SecureRandom.uuid, gig_id: c.gig_id, seat_ids: c.seat_ids, name: c.name, email: c.email)
        events << Events::SeatsReserved.new(aggregate_id: c.gig_id, order_id: order_id, seat_ids: c.seat_ids)
        events.each do |e|
          DBModels::Event.create(aggregate_id: e.aggregate_id, type: e.class.to_s, user_id: nil, body: JSON.generate(e.serialize))
        end
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
      when Events::SeatsReserved
        reservations[event.aggregate_id] += event.seat_ids.map { |s| ReadModels::Reservation.new(s) }
        reservations
      else
        reservations
      end
    end

    def update_reserved_seats(seats, event)
      case event
      when Events::SeatsReserved
        seats[event.aggregate_id] += event.seat_ids.size
        seats
      else
        seats
      end
    end

    def update_orders(orders, event)
      case event
      when Events::OrderPlaced
        orders[event.gig_id] << ReadModels::Order.new(event.name, event.email, event.seat_ids)
        orders
      else
        orders
      end
    end

    def fetch_events
      DBModels::Event.order(:created_at).map do |event|
        klass = Object.const_get(event[:type])
        body = JSON.parse(event[:body])
        klass.new(body.merge(aggregate_id: event[:aggregate_id]))
      end
    end
end
