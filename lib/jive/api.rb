require 'date'
require 'hashery/lru_hash'
require 'httparty'
require 'uri'

require 'jive/cache'
require 'jive/container'
require 'jive/content'
require 'jive/attachment'
require 'jive/person'
require 'jive/place'

module Jive
  class Api
    attr_reader :object_cache, :auth
    attr_accessor :contentlist_cache
    include HTTParty

    disable_rails_query_string_format

    def inspect
      # Don't show the attribute cache. It gets enormous. 
      attributes_no_object_cache = self.instance_variables.reject { |var| var.to_s == '@object_cache' }
      attributes_as_nice_string = attributes_no_object_cache.map { |attr| "#{attr}: #{self.instance_variable_get(attr).inspect}" }.join ", "
      "#<#{self.class}:#{'%x' % (self.object_id << 1)} #{attributes_as_nice_string}>"
    end

    class JSONResponseParser < HTTParty::Parser
      SupportFormats = { "application/json" => :json }
      def parse
        body.slice!(/throw.*;\s*/)
        super
      end
    end

    def initialize username, password, uri, cache_type=Cache::Memcache
      @urllist_cache     = cache_type.new('localhost:11211', :namespace => "urllist_cache", :compress => true)
      @objectdata_cache  = cache_type.new('localhost:11211', :namespace => "objectdata_cache", :compress => true)
      @contentlist_cache = cache_type.new('localhost:11211', :namespace => "contentlist_cache", :compress => true)
      @container_cache   = cache_type.new('localhost:11211', :namespace => "container_cache", :compress => true, :value_max_bytes => 1024*1024*16)
      @uri_cache = Hashery::LRUHash.new 1000000
      @auth = { :username => username, :password => password }
      self.class.base_uri uri
    end

    def api_version 
      self.class.get '/api/version', {:basic_auth => @auth}
    end

    def paginated_get path, options = {}, &block
      result = []
      next_uri = path

      limit = 0
      # count doesn't work as expected in paginated requests, so we have a limit option
      if options.has_key? :limit
        limit = options[:limit].to_i
        options.delete :limit
      end
      
      results_so_far = 0
      begin
        key = next_uri + options.to_s
        if @uri_cache.has_key? key
          parsed_response=@uri_cache[key]
        else 
          response=self.class.get(next_uri, options.merge({:basic_auth => @auth}))
          raise Error unless response.response.code == "200"
          parsed_response=response.parsed_response
          @uri_cache[key]=parsed_response
        end
        options.delete :query
        next_uri = (parsed_response["links"] and parsed_response["links"]["next"] ) ? parsed_response["links"]["next"] : nil
        list = parsed_response["list"]
        list = list ? list : []
        result.concat list
        if block_given?
          list.map do |item| 
            begin
              yield init_content_class(item)
            rescue
              nil # TODO: error logging?
            end
          end.compact
        end
        results_so_far += list.count 
      end while next_uri && ((limit == 0) || (results_so_far < limit))
      result
    end

    def resolve_content_class(type)
      class_name = type.capitalize
      if Jive.const_defined?(class_name)
        Jive.const_get class_name
      else
        Jive.const_set class_name, Class.new(Jive::Content)
      end
    end

    def init_content_class(item)
      resolve_content_class(item['type']).new(self, item)
    end

    def people options = {}, &block
      get_containers_by_type 'people', options, &block
    end

    def person_by_username username
      get_container_by_uri "/api/core/v3/people/username/#{username}"
    end

    def place_by_id place_id
      get_container_by_uri "/api/core/v3/places/#{place_id}"
    end

    def content_by_id conrtent_id
      get_container_by_uri "/api/core/v3/contents/#{content_id}"
    end

    def places options = {}, &block
      get_containers_by_type 'places', options, &block
    end

    def contents options = {}, &block
      get_containers_by_type 'contents', options, &block
    end

    def activities options = {}, &block
      get_containers_by_type 'activity', options, &block
    end

    def get_containers_by_type type, options, &block
      next_uri = "/api/core/v3/#{type}"
      if block_given?
        paginated_get(next_uri,options, &block)
      else
        unless data_arr=@container_cache.get(next_uri+options.to_s) 
          data_arr=paginated_get(next_uri, options)
          @container_cache.set(next_uri+options.to_s,data_arr)
        end
        data_arr.map do |data|
          object_class = Jive.const_get "#{data['type'].capitalize}"
          object_class.new self, data
        end
      end
    end

    def get_container_by_uri uri
      # Deliver from the object cache if we have it
      #return @object_cache[uri] if @object_cache.has_key? uri
      if last_part=uri.match(/https?:\/\/[^\/]*(\/.*)/)
        uri=last_part[0]
      end
      if parsed_response=@objectdata_cache.get(uri)
        # puts "Container returned from cache: #{uri}"
      else
        # puts "Container returned from server: #{uri}"
        res = self.class.get uri, { :basic_auth => @auth }
        parsed_response=res.parsed_response
        return nil if parsed_response.has_key? 'error'
        @objectdata_cache.set(uri,parsed_response)
      end
      # We handle both lists and single items with this
      if parsed_response.has_key? "list"
        parsed_response['list'].map do |item|
          object_class = Jive.const_get "#{item['type'].capitalize}"
          object_class.new self, item
        end
      else
        object_class = Jive.const_get "#{parsed_response['type'].capitalize}"
        object_class.new self, parsed_response
      end
    end

    def places_by_filter filter, options = {}
      options.merge!({ :query => { :filter => filter }})
      places options 
    end

    def places_by_type object_type, options = {}
      places_by_filter "type(#{object_type})", options
    end

    def blogs(options = {}) 
      places_by_type "blog", options
    end 

    def spaces(options = {})
      places_by_type "space", options
    end

    def groups(options = {})
      places_by_type "group", options
    end

    def contents_by_username username
      user = person_by_username username
      contents :query => { :filter => "author(#{user.self_uri})" }
    end

    def search type, query, filters = []
      filters += ["search(#{query})"]
      paginated_get("/api/core/v3/search/#{type}", { :query => { :filter => filters } } ).map do |data|
        object_class = Jive.const_get "#{data['type'].capitalize}"
        object_class.new self, data
      end
    end

    def main_space
      get_container_by_uri "/api/core/v3/places/root"
    end

    headers 'Accept' => 'application/json'
    headers 'Content-Type' => 'application/json'
    format :json
    parser JSONResponseParser

  end
end
