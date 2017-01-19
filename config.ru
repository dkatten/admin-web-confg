require 'sinatra/base'
require_relative './admin-web-config'

class MyApp < Sinatra::Base
  register Config::ConfigDetails
end

run MyApp
