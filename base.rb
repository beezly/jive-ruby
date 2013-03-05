require 'rubygems'
require 'httparty'
require 'uri'

class JiveContainer
  attr_reader :name, :type, :id, :raw_data, :self_uri
  
  def initialize instance, data
    @raw_data = data
    @api_instance = instance
    @name = data["name"]
    @type = data["type"]
    @id = data["id"]
    @display_name = data["displayName"]
    @self_uri = data["resources"]["self"]["ref"]
    @parent_uri = data["parent"]
  end

  def parent
    ret = @api_instance.class.get @parent_uri
    Object.const_get("Jive#{type.capitalize}").new @api_instance, ret
  end
end

class JiveContent < JiveContainer
  def initialize instance, data
    super instance, data
  end
end

class JiveDocument < JiveContent
end

class JiveDiscussion < JiveContent
end

class JiveFile < JiveContent
end

class JivePoll < JiveContent
end

class JiveBlogPost < JiveContent
  def initialize instance, data
    super instance, data
    @comments_uri = data["resources"]["comments"]["ref"]
    @attachments_uri = data["resources"]["attachments"]["ref"]
  end

  def comments
    @api_instance.paginated_get(@comments_uri).map { |comment| JiveContent.new @api_instance, comment } if @comments_uri
  end

  def attachments
    @api_instance.paginated_get(@attachments_uri).map { |attachment| JiveContent.new @api_instance, attachment } if @attachments_uri
  end
end

class JivePerson < JiveContainer
  attr_reader :display_name, :username, :status
  
  def initialize instance, data
    super instance, data 
    @username = data["username"]
    @status = data["status"]
  end
  
  def blog
    ret = @api_instance.class.get "/api/core/v3/people/#{@id}/blog"
    raise ret if ret.has_key? 'error'
    JiveBlog.new @api_instance, ret
  end
end

class JivePlace < JiveContainer
  attr_reader :description, :status, :parent, :ref, :html_uri
  
  def initialize instance, data
    super instance, data 
    @description = data["description"]
    @status = data["status"]
    @parent = data["parent"]
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
end

class JiveSpace < JivePlace
  def initialize instance, data
    super instance, data
  end
end

class JiveBlog < JivePlace
  def initialize instance, data
    super instance, data
    @contents_uri = data["resources"]["contents"]["ref"]
  end
  
  def posts
    @api_instance.paginated_get(@contents_uri).map { |post| JiveBlogPost.new @api_instance, post }
  end

end

class JiveApi
  include HTTParty

  class JiveParser < HTTParty::Parser
    SupportFormats = { "application/json" => :json }
    def parse
      body.slice!(/throw.*;\s*/)
      super
    end
  end
  
  def initialize username, password, uri
    @auth = { :username => username, :password => password }
    self.class.base_uri uri
  end
  
  def api_version 
    self.class.get '/api/version'
  end
  
  def paginated_get path, options = {}, &block
    result = []
    next_uri = path
    begin
      response = self.class.get next_uri, options
      options.reject! { |k,v| k == :query }
      next_uri = (response.parsed_response["links"] and response.parsed_response["links"]["next"] ) ? response.parsed_response["links"]["next"] : nil
      list = response.parsed_response["list"]
      result.concat list
      yield list if block_given?
    end while next_uri
    result
  end
  
  def people options = {}, &block
    if block 
      paginated_get('/api/core/v3/people', options) { |list| block.call list }
    else 
      paginated_get('/api/core/v3/people', options).map { |person| JivePerson.new self, person }
    end
  end
  
  def person_by_username username
    ret = self.class.get "/api/core/v3/people/username/#{username}"
    raise ret if ret.has_key? 'error'
    JivePerson.new self, ret
  end
  
  def places options = {}, &block
    if block 
      paginated_get('/api/core/v3/places', options) { |list| block.call list }
    else 
      paginated_get('/api/core/v3/places', options).map { |place| JivePlace.new self, place }
    end
  end

  def contents options = {}, &block
    if block
      paginated_get('/api/core/v3/contents', options) { |list| block.call list }
    else 
      paginated_get('/api/core/v3/contents', options).map { |content| JiveContent.new self, content }
    end
  end
  
  def activities options = {}, &block
    if block 
      paginated_get('/api/core/v3/activities', options) { |list| block.call list }
    else 
      paginated_get('/api/core/v3/activities', options).map { |activity| JiveActivity.new self, activity }
    end
  end
  
  def places_by_filter filter
    ret = []
    places :query => { :filter => "#{filter}" } do |list|
      ret << list.map do |item|
        object_class = Object.const_get "Jive#{item['type'].capitalize}"
        object_class.new self, item
      end
    end
    ret.flatten 1
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
  
  headers 'Accept' => 'application/json'
  headers 'Content-Type' => 'application/json'
  format :json
  parser JiveParser

end
