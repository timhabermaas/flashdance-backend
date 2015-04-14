require "bundler/setup"

$LOAD_PATH.unshift(File.dirname(__FILE__) + "/lib")

require "api"
require "app"

database_url = ENV.fetch("DATABASE_URL") { "postgres://localhost:5432/flashdance_development" }

app = App.new(database_url)
app.load_models!

run Api.new(app)
