require 'jive/container'

module Jive
  class Attachment < Container
    include GettableBinaryURL
    attr_reader :size, :mime_type
    
    def initialize instance, data
      super instance, data
      @mime_type = data['contentType']
      @size = data['size']
      @binary_url = data['url']
    end
  end
end
