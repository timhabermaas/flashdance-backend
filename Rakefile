$LOAD_PATH.unshift(File.dirname(__FILE__) + "/lib")

require "bundler/setup"
require "sequel"
require "logger"

require "app"
require "commands"

def connect
  database_url = ENV.fetch("DATABASE_URL") { "postgres://localhost:5432/flashdance_development" }

  Sequel.connect(database_url, :loggers => [Logger.new($stdout)]).tap do |c|
    c.sql_log_level = :debug
  end
end

def build_app
  database_url = ENV.fetch("DATABASE_URL") { "postgres://localhost:5432/flashdance_development" }
  App.new(database_url, true)
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

namespace :db do
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
      gig_ids << create_gig(app, title: "#{i + 1}. Aufführung", date: DateTime.new(2013, 7, 11 + i, 20, 30, 00, '+1'))
    end

    3.times do |i|
      gig_ids << create_gig(app, title: "#{i + 4}. Aufführung", date: DateTime.new(2013, 7, 15 + i, 20, 30, 00, '+1'))
    end

    gig_ids.each do |gig_id|
      rows = []
      16.downto(3) do |i|
        rows[i] = create_row app, gig_id: gig_id, y: (-i + 16), number: i
      end

      rows[2] = create_row app, gig_id: gig_id, y: 15, number: 2
      rows[1] = create_row app, gig_id: gig_id, y: 16, number: 1


      18.times do |i|
        create_seat app, x: 15 + i, number: 1 + i, row: rows[1]
      end
      12.times do |i|
        create_seat app, x: 36 + i, number: 19 + i, row: rows[1]
      end

      24.times do |i|
        create_seat app, x: 9 + i, number: 1 + i, row: rows[2]
      end
      12.times do |i|
        create_seat app, x: 36 + i, number: 25 + i, row: rows[2]
      end


      middle_rows = rows[3..13]

      middle_rows.each do |row|
        30.times do |i|
          # left side
          create_seat app, x: 3 + i, number: 1 + i, row: row
        end
        18.times do |i|
          # right side
          create_seat app, x: 36 + i, number: 31 + i, row: row
        end
      end

      upper_rows = rows[14..15]
      upper_rows.each do |row|
        # left side
        18.times do |i|
          create_seat app, x: 3 + i, number: 1 + i, row: row
        end

        # right side
        18.times do |i|
          create_seat app, x: 36 + i, number: 19 + i, row: row
        end
      end

      highest_row = rows[16]

      21.times do |i|
        create_seat app, x: i, number: 1 + i, row: highest_row
        create_seat app, x: 33 + i, number: 22 + i, row: highest_row
      end

      [[16, 20], [16, 21], [15, 17], [15, 18], [14, 18]].each do |(row, number)|
        # TODO use SQL
        seat = DBModels::Seat.eager(:row).all.find { |s| s.row.gig_id == gig_id && s.number == number && s.row.number == row }
        seat.unusable!
        seat.save
      end
    end
  end
end
