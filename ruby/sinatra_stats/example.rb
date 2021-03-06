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
  # allow loading this page inside a iframe
  set :protection, :except => :frame_options
  # create new object used for oauth token,code requests
  AUTH = SK::SDK::Oauth.new(@@conf)
  # check session existence on each request unless on canvas page
  before do
    unless session['access_token']
      redirect '/canvas' unless request.path_info =~ /canvas/
    end
  end

  # Receives the oauth code from SalesKing, saves it to session
  # renders canvas haml
  post '/canvas' do
    if signed_request = params[:signed_request]
      r = SK::SDK::SignedRequest.new(signed_request, AUTH.secret)
      raise "invalid request #{r.data.inspect}" unless r.valid?
      # always save and set subdomain
      session['sub_domain'] = r.data['sub_domain']
      AUTH.sub_domain = session['sub_domain']
      if r.data['user_id'] # logged in
        # new session with access_token, user_id, sub_domain
        session['access_token'] = r.data['access_token']
        session['user_id'] = r.data['user_id']
        session['company_id'] = r.data['company_id']
        session['sub_domain'] = r.data['sub_domain']
      else # must authorize redirect to oauth dialog
        halt "<script> top.location.href='#{AUTH.auth_dialog}'</script>"
      end
    end
    haml :canvas
  end

  # coming back from auth dialog as redirect_url + auth code
  # Redirects to the apps iframed canvas page inside SalesKing, where we are now authenticated
  get '/canvas' do
    if params[:code]
      AUTH.get_token(params[:code])
      halt "<script> top.location.href='#{AUTH.sk_canvas_url}'</script>"
    end
    haml :canvas
  end

  post '/stats' do
    # grab data from sk, for each result page
    objs_type = params[:obj_type] # invoices, credit_notes
    AUTH.sub_domain = session['sub_domain']
    url= if objs_type == 'invoices'
            "#{AUTH.sk_url}/api/#{objs_type}?access_token=#{session['access_token']}&filter[status_closed]=1&filter[from]=2009+08+25"
          else
            "#{AUTH.sk_url}/api/#{objs_type}?access_token=#{session['access_token']}"
          end
    c = Curl::Easy.perform(url)
    # grab obj list from response body, containing json string
    data = ActiveSupport::JSON.decode(c.body_str)
    hlp = {'payments' => ['amount', 'date'],
           'invoices' => ['net_total', 'date'] }
    #collect daily chart data
    result = get_chart_data(data[objs_type], objs_type, hlp[objs_type][0], hlp[objs_type][1])
    # data is read as json by javascript from DOM
    @chart_data = ActiveSupport::JSON.encode(result)
    haml :stats
  end

  protected

  # collect date based sums for the objects and
  # @param [Hash{String=>Hash{String=>String}}] objs_ary objects in their JSON-Schema markup
  # {"payment"=>{ "amount"=>59.5, ..}, "links"=>[..]}
  # @param [String] objs_type plural name of the collection: invoices
  # @param [String] sum_fld the fieldname to sum up
  # @param [String] date_fld date fieldname used for the sum: created_at, date,..
  def get_chart_data(objs_ary, objs_type, sum_fld, date_fld)
    data ={}
    obj_type = objs_type.singularize
    objs_ary.each do |obj|
      date = Date.parse obj[obj_type][date_fld]
      data[date] ||= 0 # init day
      # sum amounts for this day
      data[date] += obj[obj_type][sum_fld]
    end
    # - detect min-max date to build x scale
    dates = data.keys.sort
    # set start date(day) for highcharts to build the date scale
    result = {:data => [],
              :start => [dates.first.year, dates.first.month, dates.first.day] }
    current = dates.first
    while current <= dates.last do
      # add values to the data-array and fill empty days with 0, labels(date) are set in js
      result[:data] << (data[current] ? data[current] : 0)
      current += 1.day
    end
    result
  end

end
