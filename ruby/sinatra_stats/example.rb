require "rubygems"
require "bundler"
Bundler.setup

require 'sinatra/base'
require "active_support/json"
require "active_support/time"
require "active_support/inflector"
require "curb"
require "haml"

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


  # check session existence on each request unless on canvas page
  before do
    unless session['access_token']
      redirect '/canvas' unless request.path_info =~ /canvas/
    end
  end

  # Receives the oauth code from SalesKing, saves it to session
  # return to index
  before '/canvas' do
    if signed_request = params[:signed_request]
      r = SignedRequest.new(signed_request, SK.app_secret)
      raise "invalid request #{r.data.inspect}" unless r.valid?
      # always save and set subdomain
      session['sub_domain'] = r.data['sub_domain']
      SK.sub_domain = session['sub_domain']
      if r.data['user_id'] # logged in
        # new session with access_token, user_id, sub_domain
        session['access_token'] = r.data['access_token']
        session['user_id'] = r.data['user_id']
        session['company_id'] = r.data['company_id']
        session['sub_domain'] = r.data['sub_domain']
      else # must authorize redirect to oauth dialog                
        halt "<script> top.location.href='#{SK.auth_dialog}'</script>"
      end
    end
    if params[:code] # coming back from auth dialog
      SK.get_token(params[:code])
      #redirect to sk internal canvas page, where we are no authenticated
      halt "<script> top.location.href='#{SK.sk_canvas_url}'</script>"
    end
  end  

  get '/canvas' do
    haml :canvas
  end

  post '/stats' do
    # grab data from sk, for each result page
    objs_type = params[:obj_type] # invoices, credit_notes
    SK.sub_domain = session['sub_domain']
    url= if objs_type == 'invoices'
            "#{SK.sk_url}/api/#{objs_type}?access_token=#{session['access_token']}&filter[status_closed]=1&filter[from]=02+01+2009"
          else
            "#{SK.sk_url}/api/#{objs_type}?access_token=#{session['access_token']}"
          end
    c = Curl::Easy.perform(url)
    # grab obj list from response body, containing json string
    data = ActiveSupport::JSON.decode(c.body_str)
    hlp = {'payments' => ['amount', 'date'], 
           'invoices' => ['net_total', 'date'], }
    #collect daily chart data
    result = get_chart_data(data[objs_type], objs_type, hlp[objs_type][0], hlp[objs_type][1])
    # data is read as json by javascript from DOM
    @chart_data = ActiveSupport::JSON.encode(result)
    haml :stats
  end

  protected

  # === Parameter
  # <Array[Hash{String=>Hash{String=>String}}]>::
  #{"payment"=>{ "amount"=>59.5, ..}, "links"=>[{"href"=>"payments/bNn1vy_gWr379bxPJQHgBF", "rel"=>"self"}]}

  def get_chart_data(objs_ary, objs_type, sum_fld, date_fld)
    data ={}
    obj_type = objs_type.singularize
    objs_ary.each do |obj|
      date = obj[obj_type][date_fld]
      data[date] ||= 0 # init day
      # sum amounts for this day
      data[date ] += obj[obj_type][sum_fld]
    end
    # - detect min-max date to build x scale
    dates = data.keys.sort
    first_day, last_day = dates.first, dates.last

    result = {:data => [], 
              :start => [first_day.year, first_day.month, first_day.day] }
    current_day = first_day
    while current_day <= last_day do
      # add values to the data-array and fill empty days with 0,
      # time-series labels(date) set in js
      result[:data] << (data[current_day] ? data[current_day] : 0)
      current_day += 1.day
    end
    result
  end

end
