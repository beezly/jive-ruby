require 'rubygems'
require 'httparty'

class JiveContainer
  attr_reader :name, :type, :id
  
  def initialize instance, data
    @raw_data = data
    @api_instance = instance
    @name = data["name"]
    @type = data["type"]
    @id = data["id"]
    @display_name = data["displayName"]
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
    JivePlace.new @api_instance, ret
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
end

class JiveApi
  include HTTParty

  class JiveParser < HTTParty::Parser
    SupportFormats = { "application/json" => :json }
    def parse
      body.slice! /throw.*;\s*/
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
      next_uri = response.parsed_response["links"]["next"] ? response.parsed_response["links"]["next"] : nil
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
  
  def activities options = {}, &block
    if block 
      paginated_get('/api/core/v3/activities', options) { |list| block.call list }
    else 
      paginated_get('/api/core/v3/activities', options).map { |activity| JiveActivity.new self, activity }
    end
  end
  
  def blogs
    places :query => { :filter => "type(blog)" }
  end
  
  def spaces
    places :query => { :filter => "type(space)" }
  end
  
  def groups
    places :query => { :filter => "type(group)" }
  end
  
  headers 'Accept' => 'application/json'
  headers 'Content-Type' => 'application/json'
  format :json
  parser JiveParser

end