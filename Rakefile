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
  app.handle(Commands::CreateGig.new(title: title, date: date))
end

def create_seat(app, x:, number:, row:)
  app.handle(Commands::CreateSeat.new(x: x, number: number, row_id: row.id))
end

def create_row(app, y:, number:)
  app.handle(Commands::CreateRow.new(y: y, number: number))
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


    16.downto(3) do |i|
      create_row app, y: (-i + 16), number: i
    end

    second_row = create_row app, y: 15, number: 2
    first_row = create_row app, y: 16, number: 1


    18.times do |i|
      create_seat app, x: 15 + i, number: 1 + i, row: first_row
    end
    12.times do |i|
      create_seat app, x: 36 + i, number: 19 + i, row: first_row
    end

    24.times do |i|
      create_seat app, x: 9 + i, number: 1 + i, row: second_row
    end
    12.times do |i|
      create_seat app, x: 36 + i, number: 25 + i, row: second_row
    end


    middle_rows = DBModels::Row.where(number: (3..13).to_a)

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

    upper_rows = DBModels::Row.where(number: [14, 15])
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

    highest_row = DBModels::Row.where(number: 16).first

    21.times do |i|
      create_seat app, x: i, number: 1 + i, row: highest_row
      create_seat app, x: 33 + i, number: 22 + i, row: highest_row
    end

    [[16, 20], [16, 21], [15, 17], [15, 18], [14, 18]].each do |(row, number)|
      seat = DBModels::Seat.all.find { |s| s.number == number && s.row.number == row }
      seat.unusable!
      seat.save
    end

    3.times do |i|
      create_gig app, title: "#{i + 1}. Aufführung", date: DateTime.new(2013, 7, 11 + i, 20, 30, 00, '+1')
    end

    3.times do |i|
      create_gig app, title: "#{i + 4}. Aufführung", date: DateTime.new(2013, 7, 15 + i, 20, 30, 00, '+1')
    end
  end
end
