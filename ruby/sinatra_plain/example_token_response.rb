require 'rubygems'
require 'sinatra'
require 'active_support/json'
require 'curb'
require 'cgi'


get "/" do
  # settings
  @id = 'cb2c04479e11ac3f'
  @secret = 'de7f3df05ae1ec0390c55eb60bcdaeb6'
  @url = 'http://localhost:4567'
  @scope = 'api/clients:read'
  @sk_url = 'http://demo.salesking.local:3000'

  unless code = params["access_token"] # redirect to authorize url
    dialog_url = "#{@sk_url}/oauth/authorize?client_id=#{@id}&scope=#{CGI::escape(@scope)}&redirect_uri=#{CGI::escape(@url)}&response_type=token"
    redirect dialog_url
  end

  access_token = params["access_token"]
  # build current user URL
  usr_url = "#{@sk_url}/api/users/current?access_token=#{access_token}"
  # GET info about current user
  u = Curl::Easy.perform(usr_url)
  usr = ActiveSupport::JSON.decode(u.body_str)
  "King: #{usr['user']['email']}"
end
