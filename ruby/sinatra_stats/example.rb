require "rubygems"
require "bundler"
Bundler.setup

require 'sinatra/base'
require "active_support/json"
require "active_support/time" #CoreExtensions::Numeric::Time
require "curb"
require "haml"
require "redis"

require "lib/signed_request"
require "lib/sk_oauth"

class Example < Sinatra::Base
  # load settings
  @@conf = YAML.load_file(File.join(File.dirname(__FILE__), 'settings.yml'))
  # setup encrypted cookie store .. your real app should probably keep the session in redis or such
  use Rack::Session::Cookie, :key => 'sk-app-sinatra-stats',
                             :expire_after => 2592000,
                             :secret=> @@conf['session_secret']
  enable :sessions
  # set public dir to load js
  set :public, File.dirname(__FILE__) + '/public'
  # create new sk object used for oauth token,code requests
  SK = SkOauth.new(@@conf)


  # check session existence on each request and set current_user
  before do
    unless session['access_token']
      redirect '/canvas' unless request.path_info =~ /canvas/# please login
    end
  end

  before '/canvas' do
    if signed_request = params[:signed_request]
      r = SignedRequest.new(signed_request, SK.app_secret)
      raise "invalid request #{r.data.inspect}" unless r.valid?
      if r.data['user_id'] # logged in
        # new session with access_token, user_id, sub_domain
        session['access_token'] = r.data['access_token']
        session['user_id'] = r.data['user_id']
        session['company_id'] = r.data['company_id']
        session['sub_domain'] = r.data['sub_domain']
      else # must authorize redirect to oauth dialog
        SK.sub_domain = r.data['sub_domain']
        session['sub_domain'] = r.data['sub_domain']
        halt "<script> top.location.href='#{SK.auth_dialog}'</script>"
      end
    end
    if params[:code] # coming back from auth dialog
      SK.sub_domain = session['sub_domain']
      SK.get_token(params[:code])
      #redirect to sk internal canvas page, where we are no authenticated
      halt "<script> top.location.href='#{SK.sk_canvas_url}'</script>"
    end
  end

  # Receives the oauth code from SalesKing, saves it to session and return to index
  # show form with select:
  # - payments, invoices, estimates
  # - Date from / Date to
  get '/canvas' do
    haml :canvas
  end

  post '/stats' do
    # grab data from sk, for each result page
    obj_type = params[:obj_type]
    SK.sub_domain = session['sub_domain']
    url = "#{SK.sk_url}/api/#{obj_type}?access_token=#{session['access_token']}"
    c = Curl::Easy.perform(url)
    # grab obj list from response body, containing json string
    ret = ActiveSupport::JSON.decode(c.body_str)
    #collect daily chart data
    data = {}
    ret[obj_type].each do |obj|
      date = obj['payment']['date']
      # init day
      data[date] ||= 0
      # sum amounts for this day
      data[date ] += obj['payment']['amount']
    end
    # - detect min-max date to build x scale
    dates = data.keys.sort
    first_day, last_day = dates.first, dates.last
    result = {:data => [], :start => [] }
    current_day = first_day
    while current_day <= last_day do
      # Append hash with formatted data to the array, time-series labels(date) set in js
      result[:data] << (data[current_day] ? data[current_day] : 0)
      current_day += 1.day
    end
    result[:start] = [first_day.year, first_day.month, first_day.day]
    # data is read as json by javascript from DOM
    @chart_data = ActiveSupport::JSON.encode(result)
    haml :stats
  end

end
