require 'rubygems'
require 'httparty'
require 'net/http'
require 'uri'
require 'date'
require 'hashery/lru_hash'
require 'dalli'

module Jive
  module GettableBinaryURL
    def get_binary
      binary_uri = URI @binary_url
      http = Net::HTTP.new(binary_uri.host, binary_uri.port)
      req = Net::HTTP::Get.new binary_uri.request_uri
      req.basic_auth @api_instance.auth[:username], @api_instance.auth[:password]
      response = http.request req
      response.body
    end
  end

  class Container
    attr_reader :name, :type, :id, :raw_data, :self_uri, :subject, :display_name, :html_uri

    def initialize instance, data
      @raw_data = data
      @api_instance = instance
      @name = data["name"]
      @type = data["type"] 
      @id = data["id"] if data.has_key? 'id'
      @display_name = data["displayName"] if data.has_key? 'displayName'
      @self_uri = data["resources"]["self"]["ref"] if data.has_key? 'resources' and data['resources'].has_key? 'self' and data['resources']['self'].has_key? 'ref'
      @parent_uri = data["parent"] if data.has_key? 'parent_uri'
      @subject = data["subject"] if data.has_key? 'subject'
      @html_uri = data["resources"]["html"]["ref"] if (data.has_key?('resources') && data["resources"].has_key?('html'))
    end

    def display_path
      if parent.nil? 
        "#{self.class}:#{@display_name}" 
      else 
        "#{parent.display_path}/#{self.class}:#{@display_name}"
      end
    end

    def uri
      @self_uri
    end

    def parent
      @api_instance.get_container_by_uri @parent_uri if @parent_uri
    end
  end

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

  class Content < Container
    attr_reader :updated_at, :visibility, :content_id

    def initialize instance, data
      super instance, data
      @display_name = data["name"]
      @updated_at = DateTime.iso8601 data["updated"]
      @visibility = data['visibility']
      @content = data['content']['text']
      @ref = data["resources"]["self"]["ref"]
      res=@ref.match(/\/api\/core\/v3\/contents\/([0-9]+)$/)
      @content_id = res[1] if res
    end

    def author
      # Let's try being clever here and including the data Jive already sent back
      Jive.const_get("#{@raw_data['author']['type'].capitalize}").new @api_instance, @raw_data['author']
    end
    
    def comments
      @api_instance.get_container_by_uri @comments_uri if @comments_uri
    end
    
    def get
      @content
    end

  end

  class Document < Content
    def initialize instance, data
      super instance, data
      @attachments_count = data['attachments'].length
      @content = data['content']['text']
      @content_type = data['content']['type']
      @display_name = data["subject"]
      @attachments_uri = data["resources"]["attachments"]["ref"] if data["resources"].has_key? "attachments"
    end
    
    def get
      @content
    end
    
    def attachments
      @api_instance.get_container_by_uri @attachments_uri if @attachments_uri
    end    
    
    def has_attachments?
      @attachments_count > 0
    end
    
  end

  class Discussion < Content
    def initialize instance, data
      super instance, data
      @display_name = data['subject']
      @messages_uri = data['resources']['messages']['ref']
    end
    
    def messages
      @api_instance.get_container_by_uri @messages_uri if @messages_uri
    end
  end

  class File < Content
    include GettableBinaryURL
    attr_reader :mime_type
    
    def initialize instance, data
      super instance, data
      @binary_url = data['binaryURL']
      @mime_type = data['contentType']
    end
    

  end

  class Poll < Content
    def initialize instance, data
      super instance, data
      @display_name = data['subject']
    end
  end

  class Comment < Content
  end

  class Post < Content
    def initialize instance, data
      super instance, data
      @display_name = data["subject"]
      @comments_uri = data["resources"]["comments"]["ref"] if data["resources"].has_key? "comments"
      @attachments_uri = data["resources"]["attachments"]["ref"] if data["resources"].has_key? "attachments"
    end

    def attachments
      @api_instance.get_container_by_uri @attachments_uri if @attachments_uri
    end
  end
  
  class Message < Content
    def initialize instance, data
      super instance, data
      @content = data["content"]["text"]
    end
    
    def get
      @content
    end
  end

  class Update < Content
    def initialize instance, data
      super instance, data
      @display_name = data['subject']
    end
  end

  class Favorite < Content
  end

  class Task < Content
  end

  class Idea < Content
  end

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

  class Place < Container
    attr_reader :description, :status, :ref, :place_id

    def initialize instance, data
      super instance, data 
      @description = data["description"]
      @status = data["status"]
      @place_id = @ref.match(/\/api\/core\/v3\/places\/([0-9]+)$/)[1] if @ref
    end

    def content
      if cache_result=@api_instance.contentlist_cache.get(@self_uri)
        cache_result.map {|x| @api_instance.get_container_by_uri x}
      else
        filter  = "place(#{@self_uri})"
        content_uri_list = []
        ret=@api_instance.paginated_get('/api/core/v3/contents', :query => { :filter => "#{filter}" }).map do |item|
          object_class = Jive.const_get "#{item['type'].capitalize}"
          obj = object_class.new @api_instance, item
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
        object_class = Jive.const_get "#{item['type'].capitalize}"
        object_class.new @api_instance, item
      end
    end
    
  end

  class Group < Place
    def initialize instance, data
      super instance, data
    end

    def creator
      Jive.const_get("#{@raw_data['creator']['type'].capitalize}").new @api_instance, @raw_data['creator']
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

    def initialize username, password, uri
      @urllist_cache = Dalli::Client.new('localhost:11211', :namespace => "urllist_cache", :compress => true)
      @objectdata_cache = Dalli::Client.new('localhost:11211', :namespace => "objectdata_cache", :compress => true)
      @contentlist_cache = Dalli::Client.new('localhost:11211', :namespace => "contentlist_cache", :compress => true)
      @container_cache = Dalli::Client.new('localhost:11211', :namespace => "container_cache", :compress => true)
      #@object_cache = Hashery::LRUHash.new 1000000
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

      options.merge!({:basic_auth => @auth})
      limit = 0
      # count doesn't work as expected in paginated requests, so we have a limit option
      if options.has_key? :limit
        limit = options[:limit].to_i
        options.delete :limit
      end
      
      results_so_far = 0
      begin
        if @uri_cache.has_key? next_uri+options.to_s
          parsed_response=@uri_cache[next_uri+options.to_s]
        else 
          response=self.class.get(next_uri, options)
          raise Error if response.parsed_response.has_key? 'error'
          parsed_response=response.parsed_response
          @uri_cache[next_uri+options.to_s]=parsed_response
        end
        options.delete :query
        next_uri = (parsed_response["links"] and parsed_response["links"]["next"] ) ? parsed_response["links"]["next"] : nil
        list = parsed_response["list"]
        list = list ? list : []
        result.concat list
        if block_given?
          list.map do |item| 
            yield ((Jive.const_get "#{item['type'].capitalize}").new self, item)
          end
        end
        results_so_far+=list.count 
      end while next_uri && ((limit == 0) || (results_so_far < limit))
      result
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
        data_arr=paginated_get(next_uri, options) unless data_arr=@container_cache.get(next_uri+options.to_s)
        data_arr.map do |data|
          object_class = Jive.const_get "#{data['type'].capitalize}"
          o = object_class.new self, data
        end
      end
    end

    def get_container_by_uri uri
      # Deliver from the object cache if we have it
      #return @object_cache[uri] if @object_cache.has_key? uri
      uri=last_part[0] if last_part=uri.match(/https?:\/\/[^\/]*(\/.*)/)
      if parsed_response=@objectdata_cache.get(uri)
        puts "Container returned from cache: #{uri}"
      else
        puts "Container returned from server: #{uri}"
        res = self.class.get uri, { :basic_auth => @auth }
        parsed_response=res.parsed_response
        return nil if parsed_response.has_key? 'error'
        @objectdata_cache.set(uri,parsed_response)
      end
      # We handle both lists and single items with this
      if parsed_response.has_key? "list"
        all=parsed_response['list'].map do |item|
          object_class = Jive.const_get "#{item['type'].capitalize}"
          o = object_class.new self, item
        end
        #@object_cache[uri] = all
      else
        object_class = Jive.const_get "#{parsed_response['type'].capitalize}"
        o = object_class.new self, parsed_response
        #@object_cache[uri] = o
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
