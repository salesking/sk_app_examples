class Example < Sinatra::Base
  # load settings
  @@conf = YAML.load_file(File.join(File.dirname(__FILE__), 'settings.yml'))
  # setup encrypted cookie store .. your real app should probably keep the session in redis or such
  use Rack::Session::Cookie, :key => 'sk-app-sinatra-example',
                             :expire_after => 2592000,
                             :secret=> @@conf['session_secret']
  enable :sessions

  # check session existence on each request and set current_user
  before do
    if session['access_token'] && session['subdomain']
      c = Curl::Easy.perform("#{sk_url}/api/users/current?access_token=#{session['access_token']}")
      @current_user = ActiveSupport::JSON.decode(c.body_str)['user']
    end
  end

  #index
  get "/" do
    out = '<h1>Hello this is an example SalesKing app</h1>'
    # show form for subdomain
    out << "<p>Please insert your SalesKing subdomain</p>
            <form action='/' method='get'><input type='text' name='subdomain'><input type='submit'</form>" unless session['subdomain']
    # save subdomain to cookie if present
    session['subdomain'] = params['subdomain'] if params['subdomain']
    
    if @current_user
      out << "<h2>Glad you made it King: #{@current_user['email']}</h2>"
    elsif session['subdomain']
      authorize_url = "#{sk_url}/oauth/authorize?client_id=#{@@conf['id']}&redirect_uri=#{oauth_redirect_uri}&scope=invoices:read,destroy,update clients:read,destroy"
      out << "<p><a href=#{authorize_url}>now go and allow this app to access your SK account</a></p>"
    end
    out
  end

  # Receives the oauth code from SalesKing, saves it to session and return to index
  get '/sk_auth/callback' do
    tok = get_token(params[:code])
    session['access_token'] = tok['access_token']
    redirect '/'
  end

  protected

  # Makes a GET request to the token endpoint in SK and receives the
  # access token
  def get_token(code)
    url = "#{sk_url}/oauth/token?code=#{code}&client_id=#{@@conf['id']}&client_secret=#{@@conf['secret']}&redirect_uri=#{oauth_redirect_uri}"
    c = Curl::Easy.perform(url)
    # grab token from response body, containing json string
    ActiveSupport::JSON.decode(c.body_str)
  end

  # Each company has it's own subdomain so the url must be dynamic.
  # This is achived by replacing the * with the subdomain from the session
  # === Returns
  # <String>:: url
  def sk_url
    @@conf['sk_url'].gsub('*', session['subdomain'])
  end

  # === Returns
  # <String>:: dynamic creation of the redirect uri:
  #  localhost:port/sk_auth/callback   or whatever your service url is
  def oauth_redirect_uri
      uri = URI.parse(request.url)
      uri.path = '/sk_auth/callback'
      uri.query = nil
      uri.to_s
    end
end
