require "rubygems"
require 'sinatra'
require "active_support/json"
require "haml"
require "cgi"
require "curb"
require "sk_sdk/signed_request"

# settings
APP_ID = "7c8fcae8a80a3d97"
SECRET = "294f5bdbf902c8d6f894e57c88747ca9"
URL = "http://localhost:4567"
SCOPE = "invoices:update api/subs"
SK_URL = "http://demo.salesking.local:3000"

get "/" do

  unless code = params["code"] # redirect to authorize url
    dialog_url = "#{SK_URL}/oauth/authorize?client_id=#{APP_ID}&scope=#{CGI::escape(SCOPE)}&redirect_uri=#{CGI::escape(URL)}"
    redirect dialog_url
  end

  # build URL to get the access token
  token_url = "#{SK_URL}/oauth/access_token?client_id=#{APP_ID}&redirect_uri=#{CGI::escape(URL)}&client_secret=#{SECRET}&code=#{code}"
  # GET and parse access_token response json
  c = Curl::Easy.perform(token_url)
  resp = ActiveSupport::JSON.decode(c.body_str)
  # build current user URL
  usr_url = "#{SK_URL}/api/users/current?access_token=#{resp['access_token']}"
  # GET info about current user
  u = Curl::Easy.perform(usr_url)
  @user = ActiveSupport::JSON.decode(u.body_str)['user']
  
  # subscribe for a callback
  s = Curl::Easy.new("#{SK_URL}/api/subs?access_token=#{resp['access_token']}")
  s.http_post(Curl::PostField.content('sub[channel]', 'invoice.update'),
              Curl::PostField.content('sub[callback_url]', "#{URL}/invoice_create_callback"))
  @sub = ActiveSupport::JSON.decode(s.body_str)['sub']
  haml :index
  
end

post "/invoice_create_callback" do
  resp = SK::SDK::SignedRequest.new(params[:signed_request], SECRET)
  puts resp.data.inspect if resp.valid?
end


__END__

@@ layout
%html
  = yield

@@ index
%h1= "King: #{@user['email']}"
%p
  ="registered for a push notification with:"
  %br
  ="channel => #{@sub['channel']}"
  %br
  ="callback url => #{@sub['callback_url']}"
%p="Now edit an invoice in SalesKing and look into your sinatra ruby console to see the result"
