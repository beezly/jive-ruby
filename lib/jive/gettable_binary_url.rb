require 'net/http'

module Jive
  module GettableBinaryURL
    def get_binary
      binary_uri = URI @binary_url
      http = Net::HTTP.new(binary_uri.host, binary_uri.port)
      http.use_ssl = true
      req = Net::HTTP::Get.new binary_uri.request_uri
      req.basic_auth @api_instance.auth[:username], @api_instance.auth[:password]
      response = http.request req
      response.body
    end
  end
end
