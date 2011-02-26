require "rubygems"
require 'sinatra'
require "active_support/json"
require "curb"


get "/" do
  # settings
  @app_id = "APP_CLIENT_ID"
  @app_secret = "APP_SECRET"
  @app_url = "http://localhost/oauth_test"
  @app_scope = "api/clients:read"
  @sk_url = "https://SUBDOMAIN.salesking.eu"
   

  unless code = params["code"] # redirect to authorize url
    dialog_url = "#{@sk_url}/oauth/authorize?client_id=#{@app_id}&scope=#{CGI::escape(@app_scope)}&redirect_uri=#{CGI::escape(@app_url)}"
    redirect dialog_url
  end

  # build URL to get the access token
  token_url = "#{@sk_url}/oauth/access_token?client_id=#{@app_id}&redirect_uri=#{CGI::escape(@app_url)}&client_secret=#{@app_secret}&code=#{code}"
  # GET and parse access_token response json
  c = Curl::Easy.perform(token_url)
  resp = ActiveSupport::JSON.decode(c.body_str)
  # build current user URL
  usr_url = "#{@sk_url}/api/users/current?access_token=#{resp['access_token']}"
  # GET info about current user
  u = Curl::Easy.perform(usr_url)
  usr = ActiveSupport::JSON.decode(u.body_str)
  "King: #{usr['user']['email']}"
end
