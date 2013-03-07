require 'rubygems'
require 'httparty'
require 'uri'
require 'date'
require 'hashery/lru_hash'

class JiveContainer
  attr_reader :name, :type, :id, :raw_data, :self_uri, :subject
  
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

class JiveContent < JiveContainer
  attr_reader :updated_at 
  
  def initialize instance, data
    super instance, data
    @display_name = data["name"]
    @updated_at = DateTime.iso8601 data["updated"]
  end
  
  def author
    # Let's try being clever here and including the data Jive already sent back
     Object.const_get("Jive#{@raw_data['author']['type'].capitalize}").new @api_instance, @raw_data['author']
  end
  
end

class JiveDocument < JiveContent
  def initialize instance, data
    super instance, data
  end
end

class JiveDiscussion < JiveContent
  def initialize instance, data
    super instance, data
    @display_name = data['subject']
  end
end

class JiveFile < JiveContent
  def initialize instance, data
    super instance, data
  end
end

class JivePoll < JiveContent
  def initialize instance, data
    super instance, data
  end
end

class JiveComment < JiveContent
end

class JivePost < JiveContent
  def initialize instance, data
    super instance, data
    @display_name = data["subject"]
    @comments_uri = data["resources"]["comments"]["ref"] if data["resources"].has_key? "comments"
    @attachments_uri = data["resources"]["attachments"]["ref"] if data["resources"].has_key? "attachments"
  end

  def comments
    @api_instance.get_container_by_uri @comments_uri if @comments_uri
  end

  def attachments
    @api_instance.get_container_by_uri @attachments_uri if @attachments_uri
  end
end

class JiveUpdate < JiveContent
end

class JiveFavorite < JiveContent
end

class JiveTask < JiveContent
end

class JiveIdea < JiveContent
end

class JivePerson < JiveContainer
  attr_reader :display_name, :username, :status
  
  def initialize instance, data
    super instance, data 
    @username = data["username"]
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

class JivePlace < JiveContainer
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
    ret = []
    @api_instance.paginated_get '/api/core/v3/contents', :query => { :filter => "#{filter}" } do |list|
      ret << list.map do |item|
        object_class = Object.const_get "Jive#{item['type'].capitalize}"
        object_class.new self, item
      end
    end
    ret.flatten 1
  end
end

class JiveGroup < JivePlace
  def initialize instance, data
    super instance, data
  end
  
  def creator
    Object.const_get("Jive#{@raw_data['creator']['type'].capitalize}").new @api_instance, @raw_data['creator']
  end
end

class JiveSpace < JivePlace
  def initialize instance, data
    super instance, data
  end
end

class JiveProject < JivePlace
  def initialize instance, data
    super instance, data
  end
end

class JiveBlog < JivePlace
  def initialize instance, data
    super instance, data
    @display_name = data["name"]
    @contents_uri = data["resources"]["contents"]["ref"]
  end
  
  def posts
    @api_instance.paginated_get(@contents_uri).map { |post| JivePost.new @api_instance, post }
  end

end

class JiveApi
  attr_reader :object_cache
  include HTTParty
  
  disable_rails_query_string_format

  class JiveParser < HTTParty::Parser
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
    self.class.get '/api/version'
  end
  
  def paginated_get path, options = {}, &block
    result = []
    next_uri = path
    
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
      list.map {|item| yield ((Object.const_get "Jive#{item['type'].capitalize}").new self, item) } if block_given?
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
        object_class = Object.const_get "Jive#{data['type'].capitalize}"
        o = object_class.new self, data
        @object_cache[o.uri] = o
      end
    end
  end
  
  def get_container_by_uri uri
    # Deliver from the object cache if we have it
    return @object_cache[uri] if @object_cache.has_key? uri
    data = self.class.get uri
    # raise Error if data.parsed_response.has_key? 'error'
    return nil if data.parsed_response.has_key? 'error'
    # We handle both lists and single items with this
    if data.parsed_response.has_key? "list"
      data.parsed_response['list'].map do |item|
        object_class = Object.const_get "Jive#{item['type'].capitalize}"
        o = object_class.new self, item
        @object_cache[o.uri] = o
        o
      end
    else
      object_class = Object.const_get "Jive#{data.parsed_response['type'].capitalize}"
      o = object_class.new self, data
      @object_cache[o.uri] = o
      o
    end
  end
  
  def places_by_filter filter
    places ({ :query => { :filter => "#{filter}" }}) 
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
      object_class = Object.const_get "Jive#{data['type'].capitalize}"
      object_class.new self, data
    end
  end
  
  headers 'Accept' => 'application/json'
  headers 'Content-Type' => 'application/json'
  format :json
  parser JiveParser

end
