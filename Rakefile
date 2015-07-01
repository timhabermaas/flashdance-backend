$LOAD_PATH.unshift(File.dirname(__FILE__) + "/lib")

require "bundler/setup"
require "sequel"
require "logger"

require "app"
require "commands"

require "httparty"

def connect
  database_url = ENV.fetch("DATABASE_URL") { "postgres://localhost:5432/flashdance_development" }

  Sequel.connect(database_url, :loggers => [Logger.new($stdout)]).tap do |c|
    c.sql_log_level = :debug
  end
end

def build_app
  database_url = ENV.fetch("DATABASE_URL") { "postgres://localhost:5432/flashdance_development" }
  App.new(database_url, "foo", "bar", true)
end

def create_gig(app, title:, date:)
  app.handle(Commands::CreateGig.new(title: title, date: date)).id
end

def create_seat(app, x:, number:, row:)
  app.handle(Commands::CreateSeat.new(x: x, number: number, row_id: row.id))
end

def create_row(app, gig_id:, y:, number:)
  app.handle(Commands::CreateRow.new(gig_id: gig_id, y: y, number: number))
end

namespace :cleanup do
  task :orders do
    HTTParty.delete('https://tickets-backend-ruby.herokuapp.com/unfinished_orders')
  end
end

namespace :db do
  task :migrate_events do
    connection = connect
    connection[:events].each do |e|
      if e[:type] == "Events::SeatFreed" || e[:type] == "Events::SeatReserved"
        seat_id = JSON.parse(e[:body])["seat_id"]
        connection[:events].where(id: e[:id]).update(body: "{}", aggregate_id: seat_id)
      end
    end
  end

  task :migrate do
    build_app.migrate!
  end

  namespace :test do
    task :prepare do
      ENV["DATABASE_URL"] = "postgres://localhost:5432/flashdance_test"
      build_app.migrate!
    end
  end

  task :seed do
    app = build_app

    app.clean_db!
    app.load_models!

    gig_ids = []
    3.times do |i|
      gig_ids << create_gig(app, title: "#{i + 1}. Aufführung", date: DateTime.new(2015, 7, 16 + i, 20, 30, 00, '+2'))
    end

    3.times do |i|
      gig_ids << create_gig(app, title: "#{i + 4}. Aufführung", date: DateTime.new(2015, 7, 20 + i, 20, 30, 00, '+2'))
    end

    gig_ids.each do |gig_id|
      rows = []
      17.downto(1) do |i|
        rows[i] = create_row app, gig_id: gig_id, y: (-i + 17), number: i
      end


      20.times do |i|
        create_seat app, x: 8 + i, number: 1 + i, row: rows[1]
      end
      15.times do |i|
        create_seat app, x: 31 + i, number: 21 + i, row: rows[1]
      end


      middle_rows = rows[2..14]

      middle_rows.each do |row|
        25.times do |i|
          # left side
          create_seat app, x: 3 + i, number: 1 + i, row: row
        end
        15.times do |i|
          # right side
          create_seat app, x: 31 + i, number: 26 + i, row: row
        end
      end

      upper_rows = rows[15..16]
      upper_rows.each do |row|
        # left side
        15.times do |i|
          create_seat app, x: 3 + i, number: 1 + i, row: row
        end

        # right side
        15.times do |i|
          create_seat app, x: 31 + i, number: 16 + i, row: row
        end
      end

      highest_row = rows[17]

      18.times do |i|
        create_seat app, x: i, number: 1 + i, row: highest_row
        create_seat app, x: 28 + i, number: 19 + i, row: highest_row
      end
    end
  end
end
