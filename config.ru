require "bundler/setup"

$LOAD_PATH.unshift(File.dirname(__FILE__) + "/lib")

require "api"
require "app"

database_url = ENV.fetch("DATABASE_URL") { "postgres://localhost:5432/flashdance_development" }

app = App.new(database_url, ENV["USER_PASSWORD"], ENV["ADMIN_PASSWORD"])
app.load_models!
app.load_events!

run Api.new(app)
