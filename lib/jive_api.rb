require 'rubygems'
require 'httparty'
require 'net/http'
require 'uri'
require 'date'
require 'hashery/lru_hash'

module Jive
  class Container
    attr_reader :name, :type, :id, :raw_data, :self_uri, :subject, :display_name

    def initialize instance, data
      @raw_data = data
      @api_instance = instance
      @name = data["name"]
      @type = data["type"]
      @id = data["id"]
      @display_name = data["displayName"]
      @self_uri = data["resources"]["self"]["ref"]
      @parent_uri = data["parent"]
      @subject = data["subject"]
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

  class Content < Container
    attr_reader :updated_at, :visibility 

    def initialize instance, data
      super instance, data
      @display_name = data["name"]
      @updated_at = DateTime.iso8601 data["updated"]
      @visibility = data['visibility']
      @content = data['content']['text']
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
      @content = data['content']['text']
      @content_type = data['content']['type']
      @display_name = data["subject"]
    end
    
    def get
      @content
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
    attr_reader :mime_type
    
    def initialize instance, data
      super instance, data
      @binary_url = data['binaryURL']
      @mime_type = data['contentType']
    end
    
    def get
      binary_uri = URI @binary_url
      http = Net::HTTP.new(binary_uri.host, binary_uri.port)
      req = Net::HTTP::Get.new binary_uri.request_uri
      req.basic_auth @api_instance.auth[:username], @api_instance.auth[:password]
      response = http.request req
      response.body
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
    attr_reader :description, :status, :ref, :html_uri

    def initialize instance, data
      super instance, data 
      @description = data["description"]
      @status = data["status"]
      @ref = data["resources"]["self"]["ref"]
      @html_uri = data["resources"]["html"]["ref"]
    end

    def content
      filter  = "place(#{@self_uri})"
      @api_instance.paginated_get('/api/core/v3/contents', :query => { :filter => "#{filter}" }).map do |item|
        object_class = Jive.const_get "#{item['type'].capitalize}"
        object_class.new @api_instance, item
      end
    end
    
    def places filter = []
      @api_instance.paginated_get("#{uri}/places", :query => { :filter => filter }).map do |item|
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
      @object_cache = Hashery::LRUHash.new 10000
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

      # count doesn't work as expected in paginated requests, so we have a limit option
      if options.has_key? :limit
        limit = options[:limit]
        options.delete :limit
      else
        limit = nil
      end

      results_so_far = 0
      begin
        response = self.class.get next_uri, options
        raise Error if response.parsed_response.has_key? 'error'
        options.delete :query
        next_uri = (response.parsed_response["links"] and response.parsed_response["links"]["next"] ) ? response.parsed_response["links"]["next"] : nil
        list = response.parsed_response["list"]
        list = list ? list : []
        result.concat list
        if block_given?
          list.map do |item| 
            yield ((Jive.const_get "#{item['type'].capitalize}").new self, item)
          end
        end
        results_so_far+=list.count 
      end while next_uri and (limit.nil? or results_so_far < limit ) 
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
        paginated_get(next_uri, options).map do |data|
          object_class = Jive.const_get "#{data['type'].capitalize}"
          o = object_class.new self, data
          @object_cache[o.uri] = o
        end
      end
    end

    def get_container_by_uri uri
      # Deliver from the object cache if we have it
      return @object_cache[uri] if @object_cache.has_key? uri
      data = self.class.get uri, { :basic_auth => @auth }
      # raise Error if data.parsed_response.has_key? 'error'
      return nil if data.parsed_response.has_key? 'error'
      # We handle both lists and single items with this
      if data.parsed_response.has_key? "list"
        data.parsed_response['list'].map do |item|
          object_class = Jive.const_get "#{item['type'].capitalize}"
          o = object_class.new self, item
          @object_cache[o.uri] = o
          o
        end
      else
        object_class = Jive.const_get "#{data.parsed_response['type'].capitalize}"
        o = object_class.new self, data
        @object_cache[o.uri] = o
        o
      end
    end

    def places_by_filter filter
      places ({ :query => { :filter => filter }}) 
    end

    def places_by_type object_type
      places_by_filter "type(#{object_type})"
    end

    def blogs 
      places_by_type "blog"
    end 

    def spaces
      places_by_type "space"
    end

    def group
      places_by_type "group"
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
      spaces.select { |space| space.raw_data[]}
    end

    headers 'Accept' => 'application/json'
    headers 'Content-Type' => 'application/json'
    format :json
    parser JSONResponseParser

  end
end
