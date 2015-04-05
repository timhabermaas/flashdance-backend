require "sinatra/base"
require "json"

Rows = []
Seats = []

class Row
  attr_reader :y, :number

  def initialize(y:, number:)
    @y, @number = y, number
  end

  def self.create!(args={})
    Rows << Row.new(args)
  end

  def serialize
    {y: y, number: number}
  end
end

class Seat
  attr_reader :x, :number, :row, :id, :usable

  def initialize(id:, x:, number:, row:)
    @id, @x, @number, @row, @usable = id, x, number, row, true
  end

  def unusable!
    @usable = false
  end

  def self.create!(args={})
    Seats << Seat.new(args.merge(id: rand(100000)))
  end

  def serialize
    {x: x, number: number, row: row.number, id: id, usable: usable}
  end
end

16.downto(3) do |i|
  Row.create! y: (-i + 16), number: i
end

Row.create! y: 15, number: 2
Row.create! y: 16, number: 1

first_row = Rows.find { |r| r.number == 1}
second_row = Rows.find { |r| r.number == 2}

18.times do |i|
  Seat.create! x: 15 + i, number: 1 + i, row: first_row
end
12.times do |i|
  Seat.create! x: 36 + i, number: 19 + i, row: first_row
end

24.times do |i|
  Seat.create! x: 9 + i, number: 1 + i, row: second_row
end
12.times do |i|
  Seat.create! x: 36 + i, number: 25 + i, row: second_row
end


middle_rows = Rows.select { |r| (3..13).cover?(r.number) }

middle_rows.each do |row|
  30.times do |i|
    # left side
    Seat.create! x: 3 + i, number: 1 + i, row: row
  end
  18.times do |i|
    # right side
    Seat.create! x: 36 + i, number: 31 + i, row: row
  end
end

upper_rows = Rows.select { |r| (14..15).cover?(r.number) }
upper_rows.each do |row|
  # left side
  18.times do |i|
    Seat.create! x: 3 + i, number: 1 + i, row: row
  end

  # right side
  18.times do |i|
    Seat.create! x: 36 + i, number: 19 + i, row: row
  end
end

highest_row = Rows.find { |r| r.number == 16 }

21.times do |i|
  Seat.create! x: i, number: 1 + i, row: highest_row
  Seat.create! x: 33 + i, number: 22 + i, row: highest_row
end

[[16, 20], [16, 21], [15, 17], [15, 18], [14, 18]].each do |(row, number)|
  Seats.find { |s| s.number == number && s.row.number == row }.unusable!
end


class Api < Sinatra::Application
  before do
    headers "Access-Control-Allow-Origin" => "*"
  end

  get "/gigs/:gig_id/seats" do
    status 200

    body JSON.generate({seats: Seats.map(&:serialize), rows: Rows.map(&:serialize)})
  end
end
