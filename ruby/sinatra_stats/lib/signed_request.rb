### For parsing the signed request
require 'base64'
require "active_support/json"
require 'openssl'

# the code is copied from
# http://forum.developers.facebook.net/viewtopic.php?pid=250261
class SignedRequest

  attr_reader :signed_request, :app_secret, :data, :payload, :sign

  def initialize(signed_request, app_secret)
    @signed_request = signed_request
    @app_secret = app_secret
    decode_data
  end

  #Populates @data and @sign(ature) of the instance, by splitting and decoding
  #the incoming signed_request
  def decode_data
    @sign, @payload = @signed_request.split('.')
    @data = ActiveSupport::JSON.decode base64_url_decode(@payload)
  end

  # Decode a base64URL encoded string: replace - with + and _ with /, adds
  # padding so ruby's Base64 can decode it.
  # === returns
  # <String>:: the plain string decoded
  def base64_url_decode(str)
    encoded_str = str.tr('-_', '+/')
    encoded_str += '=' while !(encoded_str.size % 4).zero?
    Base64.decode64(encoded_str)
  end

  # A request is valid if the new hmac created from the incoming string matches
  # the new one, created with the apps secret
  def valid?
    return false if @data['algorithm'].to_s.upcase != 'HMAC-SHA256'
    #check sig
    @sign == OpenSSL::HMAC.hexdigest('sha256', @app_secret, @payload)
  end

  def encode

  end
end