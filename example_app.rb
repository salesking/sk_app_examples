require "rubygems"
require "bundler"
Bundler.setup

require 'sinatra/base'
require "active_support"
require "active_support/json"
require "curb"

# local
require "signed_request"
#use Rack::Session::Redis
class ExampleApp < Sinatra::Base
  use Rack::Session::Cookie, :key => 'rack.session',
                           :path => '/',
                           :expire_after => 2592000
  enable :sessions
  # load settings
  @@conf = YAML.load_file(File.join(File.dirname(__FILE__), 'settings.yml'))
  # setup redis
  DB = "sk.app.csv_stats"
#  @@redis = Redis.new(:host => "localhost", :port => 6379)


  before do
    if session['token']
      c = Curl::Easy.perform("#{@@conf['sk_url']}/api/users/current?access_token=#{session['token']}")
      @current_user = ActiveSupport::JSON.decode(c.body_str)['user']
    end
  end

  #index
  get "/" do
    out = '<p>Hello this is an example app and the start page is not protected</p>'   
    if @current_user
      out << "<h2>Glad you made it .. you are logged in as #{@current_user['email']}</h2>"
    else
      out << '<p><a href="sk_auth">now go and allow this app to access you SK account</a></p>'
    end
    out
  end

  # simply redirect to the oauth dialog in SalesKing
  get '/sk_auth' do
    url = "#{@@conf['sk_url']}/oauth/authorize?client_id=#{@@conf['app_id']}&redirect_uri=#{oauth_redirect_uri}&scope=invoices, clients"
    redirect url
  end

  # Receives the oauth code from SalesKing and makes a request to grad the access token
  #
  get '/sk_auth/callback' do
    tok = get_token(params[:code])
    puts tok.inspect
    session['token'] = tok['oauth_token']
    redirect '/'
    # get user.id for the current _user
#    user = ActiveSupport::JSON.decode(oauth.get('/api/users/current'))
    # save to db, since we dont have an own user handling
#    @@redis.hmset "#{DB}.#{user['id']}",
#                  'token', oauth.token,
#                  'expires_at', oauth.expires_at
    # save token in local session
#    session['user_id'] = user['id']
    
  end

  protected

  # before_filter
  # creates a session if the user has a sk session and the app is allowed
  def check_sk_auth
    if !current_user.session
      oauth_token = nil
      if params[:signed_request]
        signed_data = SignedRequest.new(params[:signed_request], @@conf['app_secret']).valid?
        if signed_data['oauth_token']
          oauth_token = oauth_client.access_token_by_token(signed_data['oauth_token'])
        else
          return redirect_to oauth_client.authorize_url(:redirect_uri => oauth_redirect_uri)
        end
      else
        return redirect_to oauth_client.authorize_url(:redirect_uri => oauth_redirect_uri)
      end

      # create local session for the user
      if resource && resource.persisted? && resource.errors.empty?
        session[:oauth_token] = oauth_token # This is stored in Redis
        session[:expires_at] = signed_data['expires_at'] # This is stored in Redis
      else
        session[:oauth_token] = nil
      end
    else
      nil
    end
  end

  # === Returns
  # <OAuth2::Client>:: memoized oauth client class
  def oauth_client
    @oauth_client ||= OAuth2::Client.new(@@conf['app_id'], 
                                         @@conf['app_secret'], 
                                         :site => @@conf['sk_url'])
  end
  
  def get_token(code)
    url = "#{@@conf['sk_url']}/oauth/access_token?code=#{code}&client_id=#{@@conf['app_id']}&client_secret=#{@@conf['app_secret']}&redirect_uri=#{oauth_redirect_uri}"
    c = Curl::Easy.new(url)
    c.perform
    # grab token from response body, containing json string
    ActiveSupport::JSON.decode(c.body_str)
  end


  def oauth_redirect_uri
      uri = URI.parse(request.url)
      uri.path = '/sk_auth/callback'
      uri.query = nil
      uri.to_s
    end
end
