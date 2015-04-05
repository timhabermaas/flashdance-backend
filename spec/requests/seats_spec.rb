ENV["DATABASE_URL"] = "postgres://localhost:5432/flashdance_test"
require "api"
require "rack/test"

DB.loggers = []

def app
  Api.new
end

def json_response
  JSON.parse(last_response.body)
end

def last_status
  last_response.status
end


RSpec.describe "/gigs/:id/seats" do
  include Rack::Test::Methods

  before(:all) do
    Sequel.extension :migration, :core_extensions
    Sequel::Migrator.run(DB, File.dirname(__FILE__) + '/../../migrations')

    DB[:seats].delete
    DB[:rows].delete
  end

  before do
    row = DBModels::Row.create y: 1, number: 2
    DBModels::Seat.create x: 1, number: 3, row: row, usable: false
    DBModels::Seat.create x: 2, number: 4, row: row

    get "/gigs/4/seats"
  end

  it "returns the seats" do
    expect(last_status).to eq 200
    expect(json_response["seats"].size).to eq 2
    expect(json_response["seats"].first["number"]).to eq 3
    expect(json_response["seats"].first["x"]).to eq 1
    expect(json_response["seats"].first["row"]).to eq 2
    expect(json_response["seats"].first["usable"]).to eq false
    expect(json_response["seats"].last["number"]).to eq 4
    expect(json_response["seats"].last["x"]).to eq 2
    expect(json_response["seats"].last["row"]).to eq 2
    expect(json_response["seats"].last["usable"]).to eq true
  end
end
