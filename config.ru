require "bundler/setup"

$LOAD_PATH.unshift(File.dirname(__FILE__) + "/lib")

require "api"

run Api.new
