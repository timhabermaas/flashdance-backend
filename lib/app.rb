require "command_handlers"
require "query_handlers"
require "commands"
require "queries"
require "events"
require "aggregates"
require "read_models"
require "sendgrid_mailer"

require "sequel"
require "securerandom"

class ReadRepository
  attr_reader :orders
  attr_reader :full_seats_count

  def initialize
    reset!
  end

  def reset!
    @orders = {}
    @full_seats_count = Hash.new(0)
  end

  def update!(event)
    case event
    when Events::OrderStarted
      @orders[event.aggregate_id] = ReadModels::Order.new(event.aggregate_id, event.name, event.email, [], false, 0, event.created_at)
    when Events::OrderNumberSet
      @orders[event.aggregate_id].number = event.number
    when Events::SeatAddedToOrder
      @orders[event.aggregate_id].add_seat(event.seat_id)
    when Events::SeatRemovedFromOrder
      @orders[event.aggregate_id].remove_seat(event.seat_id)
    when Events::ReducedTicketsSet
      @orders[event.aggregate_id].reduced_count = event.reduced_count
    when Events::OrderFinished
      @orders[event.aggregate_id].finish!
    when Events::OrderPaid
      @orders[event.aggregate_id].pay!
    when Events::SeatReserved
      @full_seats_count[event.aggregate_id] += 1
    end
  end
end

class PrintMailer
  def send_confirmation_mail order
    puts "SENDING E-MAIL WITH INFOS"
    p order
    puts
  end
end

class App
  class DomainError < StandardError; end
  class RecordNotFound < StandardError; end
  class SeatAlreadyReserved < DomainError; end
  class SeatNotReserved < DomainError; end

  def initialize(database_url, user_pw, admin_pw, logging=true)
    loggers = logging ? [Logger.new($stdout)] : []
    @connection = Sequel.connect(database_url, loggers: loggers)
    Sequel.application_timezone = "Berlin"
    Sequel.database_timezone = "UTC"
    Sequel::Model.plugin :timestamps

    if ENV["SENDGRID_PASSWORD"] && ENV["SENDGRID_USERNAME"]
      @mailer = SendgridMailer.new(ENV["SENDGRID_USERNAME"], ENV["SENDGRID_PASSWORD"])
    else
      @mailer = PrintMailer.new
    end
    @users = { "user" => {password: user_pw, role: "user"}, "admin" => {password: admin_pw, role: "admin"} }
    @read_repo = ReadRepository.new
  end

  # FIXME Remove this method by not using Sequel models.
  def load_models!
    require "models"
  end

  def load_events!
    fetch_events.each do |event|
      @read_repo.update!(event)
    end
  end

  def login(user, password)
    # TODO broken return type
    if user = @users[user]
      if user[:password] == password
        user[:role]
      else
        false
      end
    else
      false
    end
  end

  def answer(query)
    {
      Queries::ListFinishedOrders => answerer { |q|
        @read_repo.orders.values.select(&:finished?)
      },
      Queries::ListReservationsForGig => answerer { |q|
        fetch_events_for(aggregate_id: q.gig_id).reduce(Hash.new { |h, key| h[key] = []}, &self.method(:update_reservations))[q.gig_id]
      },
      Queries::GetFreeSeats => answerer { |q|
        reserved_seats = @read_repo.full_seats_count[q.gig_id]
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
      Commands::PayOrder => handler do |c|
        events = fetch_events_for(aggregate_id: c.order_id)
        if events.empty?
          raise ArgumentError
        else
          persist_events([Events::OrderPaid.new(aggregate_id: c.order_id)])
        end
      end,
      Commands::StartOrder => handler do |c|
        order_id = SecureRandom.uuid
        persist_events([Events::OrderStarted.new(aggregate_id: order_id, name: c.name, email: c.email), Events::OrderNumberSet.new(aggregate_id: order_id, number: @connection[:events].count + 1000)])
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
        raise RecordNotFound.new if order_events.empty?
        order = fetch_domain(klass: Aggregates::Order, aggregate_id: c.order_id)
        events = order.finish!(c.reduced_count, c.type)
        persist_events(events)
        order = @read_repo.orders[c.order_id]
        @mailer.send_confirmation_mail(order)
      end,
      Commands::FinishOrderWithAddress => handler do |c|
        order_events = fetch_events_for(aggregate_id: c.order_id)
        raise RecordNotFound.new if order_events.empty?
        order = fetch_domain(klass: Aggregates::Order, aggregate_id: c.order_id)
        events = order.finish_and_deliver!(c.reduced_count, c.street, c.postal_code, c.city)
        persist_events(events)
        order = @read_repo.orders[c.order_id]
        @mailer.send_confirmation_mail(order)
      end
    }.fetch(command.class).handle(command)
  end

  def clean_db!
    @connection[:seats].delete
    @connection[:rows].delete
    @connection[:gigs].delete
    @connection[:events].delete
    @read_repo.reset!
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
      events.each { |e| @read_repo.update!(e) }
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
