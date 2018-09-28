require 'jive/container'
require 'jive/gettable_binary_url'

module Jive
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

    def content_methods
      self.methods - Object.methods
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
    attr_reader :mime_type, :binary_url
    
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
end
