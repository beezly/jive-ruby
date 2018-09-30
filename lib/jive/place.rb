require 'jive/container'

module Jive
  class Place < Container
    attr_reader :description, :status, :ref, :place_id

    def initialize instance, data
      super instance, data 
      @description = data["description"]
      @status = data["status"]
      @place_id = @self_uri.match(/\/api\/core\/v3\/places\/([0-9]+)$/)[1] 
    end

    def content
      if cache_result=@api_instance.contentlist_cache.get(@self_uri)
        cache_result.map {|x| @api_instance.get_container_by_uri x}
      else
        filter  = "place(#{@self_uri})"
        content_uri_list = []
        ret=@api_instance.paginated_get('/api/core/v3/contents', :query => { :filter => "#{filter}" }).map do |item|
          obj = init_content_class(item)
          content_uri_list.push obj.self_uri
          obj
        end
        @api_instance.contentlist_cache.set(@self_uri,content_uri_list)
        puts "wrote #{content_uri_list} to contentlist cache"
        ret
      end
    end

    def places(filter = [], options = {})
      options.merge!({ :filter => filter })
      @api_instance.paginated_get("#{uri}/places", :query => options).map do |item|
        init_content_class(item)
      end
    end
    
  end

  class Group < Place
    def initialize instance, data
      super instance, data
    end

    def creator
      init_content_class(@raw_data['creator'])
    end
  end

  class Space < Place
    def initialize instance, data
      super instance, data
    end
    
    def sub_spaces
      places ["type(space)"]
    end
  end

  class Project < Place
    def initialize instance, data
      super instance, data
    end
  end

  class Blog < Place
    def initialize instance, data
      super instance, data
      @display_name = data["name"]
      @contents_uri = data["resources"]["contents"]["ref"]
    end

    def posts
      @api_instance.paginated_get(@contents_uri).map { |post| Post.new @api_instance, post }
    end

  end
end
