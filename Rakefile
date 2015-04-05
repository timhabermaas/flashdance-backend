$LOAD_PATH.unshift(File.dirname(__FILE__) + "/lib")

require "bundler/setup"
require "sequel"
require "logger"

def connect
  database_url = ENV.fetch("DATABASE_URL") { "postgres://localhost:5432/flashdance_development" }

  Sequel.connect(database_url, :loggers => [Logger.new($stdout)]).tap do |c|
    c.sql_log_level = :debug
  end
end

namespace :db do
  task :migrate do
    Sequel.extension :migration, :core_extensions
    Sequel::Migrator.run(connect, File.dirname(__FILE__) + '/migrations')
  end

  namespace :test do
    task :prepare do
      ENV["DATABASE_URL"] = "postgres://localhost:5432/flashdance_test"
      Sequel.extension :migration, :core_extensions
      Sequel::Migrator.run(connect, File.dirname(__FILE__) + '/migrations')
    end
  end

  task :seed do
    connect

    require "models"

    DBModels::Row.dataset.delete
    DBModels::Seat.dataset.delete
    DBModels::Gig.dataset.delete

    3.times do |i|
      DBModels::Gig.create title: "#{i + 1}. Aufführung", date: DateTime.new(2013, 7, 11 + i, 20, 30, 00, '+1')
    end

    3.times do |i|
      DBModels::Gig.create title: "#{i + 4}. Aufführung", date: DateTime.new(2013, 7, 15 + i, 20, 30, 00, '+1')
    end

    16.downto(3) do |i|
      DBModels::Row.create y: (-i + 16), number: i
    end

    second_row = DBModels::Row.create y: 15, number: 2
    first_row = DBModels::Row.create y: 16, number: 1


    18.times do |i|
      DBModels::Seat.create x: 15 + i, number: 1 + i, row: first_row
    end
    12.times do |i|
      DBModels::Seat.create x: 36 + i, number: 19 + i, row: first_row
    end

    24.times do |i|
      DBModels::Seat.create x: 9 + i, number: 1 + i, row: second_row
    end
    12.times do |i|
      DBModels::Seat.create x: 36 + i, number: 25 + i, row: second_row
    end


    middle_rows = DBModels::Row.where(number: (3..13).to_a)

    middle_rows.each do |row|
      30.times do |i|
        # left side
        DBModels::Seat.create x: 3 + i, number: 1 + i, row: row
      end
      18.times do |i|
        # right side
        DBModels::Seat.create x: 36 + i, number: 31 + i, row: row
      end
    end

    upper_rows = DBModels::Row.where(number: [14, 15])
    upper_rows.each do |row|
      # left side
      18.times do |i|
        DBModels::Seat.create x: 3 + i, number: 1 + i, row: row
      end

      # right side
      18.times do |i|
        DBModels::Seat.create x: 36 + i, number: 19 + i, row: row
      end
    end

    highest_row = DBModels::Row.where(number: 16).first

    21.times do |i|
      DBModels::Seat.create x: i, number: 1 + i, row: highest_row
      DBModels::Seat.create x: 33 + i, number: 22 + i, row: highest_row
    end

    [[16, 20], [16, 21], [15, 17], [15, 18], [14, 18]].each do |(row, number)|
      seat = DBModels::Seat.all.find { |s| s.number == number && s.row.number == row }
      seat.unusable!
      seat.save
    end
  end
end
