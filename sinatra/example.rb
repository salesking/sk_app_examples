require "rubygems"
require "bundler"
Bundler.setup

require 'sinatra/base'
require "active_support"
require "active_support/json"
require "curb"

class Example < Sinatra::Base
    # load settings
  @@conf = YAML.load_file(File.join(File.dirname(__FILE__), '..' ,'settings.yml'))
  # setup encrypted cookie store .. your real app should probably keep the session in redis or such
  use Rack::Session::Cookie, :key => 'sk-app-sinatra-example',
                             :expire_after => 2592000,
                             :secret=> @@conf['session_secret']
  enable :sessions

  # check session existence on each request and set current_user
  before do
    if session['token'] && session['subdomain']
      c = Curl::Easy.perform("#{sk_url}/api/users/current?access_token=#{session['token']}")
      @current_user = ActiveSupport::JSON.decode(c.body_str)['user']
    end
  end

  #index
  get "/" do
    out = '<h1>Hello this is an example SalesKing app</h1>'
    # show form for subdomain
    out << "<p>Please insert your SalesKing subdomain</p>
            <form action='/' method='get'><input type='text' name='subdomain'><input type='submit'</form>" unless session['subdomain']
    session['subdomain'] = params['subdomain'] if params['subdomain']
    
    if @current_user
      out << "<h2>Glad you made it .. you are logged in as #{@current_user['email']}</h2>"
    elsif session['subdomain']
      out << '<p><a href="sk_auth">now go and allow this app to access your SK account</a></p>'
    end
    out
  end

  # simply redirect to the oauth dialog in SalesKing
  get '/sk_auth' do
    redirect "#{sk_url}/oauth/authorize?client_id=#{@@conf['app_id']}&redirect_uri=#{oauth_redirect_uri}&scope=invoices, clients"
  end

  # Receives the oauth code from SalesKing, saves it to session and return to index
  get '/sk_auth/callback' do
    tok = get_token(params[:code])
    session['token'] = tok['oauth_token']
    redirect '/'
  end

  protected

  # Makes a GET request to the access_token endpoint in SK and receives the
  # oauth/access token
  def get_token(code)
    url = "#{sk_url}/oauth/access_token?code=#{code}&client_id=#{@@conf['app_id']}&client_secret=#{@@conf['app_secret']}&redirect_uri=#{oauth_redirect_uri}"
    c = Curl::Easy.new(url)
    c.perform
    # grab token from response body, containing json string
    ActiveSupport::JSON.decode(c.body_str)
  end

  # Each company has it's own subdomain so the url must be dynamic.
  # This is achived by replacing the * with the subdomain from the session
  # === Returns
  # <String>:: url
  def sk_url
    @sk_url ||= @@conf['sk_url'].gsub('*', session['subdomain'])
  end

  # === Returns
  # <String>:: dynamic creation of the redirect uri localhost:port/sk_auth/callback
  def oauth_redirect_uri
      uri = URI.parse(request.url)
      uri.path = '/sk_auth/callback'
      uri.query = nil
      uri.to_s
    end
end
