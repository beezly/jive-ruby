require 'jive/container'

module Jive
  class Person < Container
    attr_reader :display_name, :userid, :status

    def initialize instance, data
      super instance, data 
      @userid = data["jive"]["username"]
      @status = data["status"]
      @blog_uri = data["resources"]["blog"]["ref"] if data["resources"].has_key? 'blog'
    end

    def blog
      @blog_uri ? @api_instance.get_container_by_uri(@blog_uri) : nil
    end

    def content filters = []
      filters += ["author(#{uri})"]
      @api_instance.contents :query => { :filter => filters }
    end
  end
  
  class User < Person
  end

end
