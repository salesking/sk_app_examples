### For parsing the signed request
require 'base64'
require 'active_support'
require 'openssl'

# the code is copied from
# http://forum.developers.facebook.net/viewtopic.php?pid=250261
class SignedRequest

  attr_reader :signed_request, :app_secret

  def initialize(signed_request, app_secret)
    @signed_request = signed_request
    @app_secret = app_secret
  end

  def base64_url_decode str
    encoded_str = str.gsub('-','+').gsub('_','/')
    encoded_str += '=' while !(encoded_str.size % 4).zero?
    Base64.decode64(encoded_str)
  end

  def valid?
    #decode data
    encoded_sig, payload = signed_request.split('.')
    sig = base64_url_decode(encoded_sig).unpack("H*")[0]
    data = ActiveSupport::JSON.parse base64_url_decode(payload)
    return false if data['algorithm'].to_s.upcase != 'HMAC-SHA256'
   
    #check sig
    expected_sig = OpenSSL::HMAC.hexdigest('sha256', @app_secret, payload)
    return false if expected_sig != sig
    data
  end

  def encode

  end
end