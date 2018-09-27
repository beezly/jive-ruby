module Jive
  class Container
    attr_reader :name, :type, :id, :raw_data, :self_uri, :subject, :display_name, :html_uri

    def initialize instance, data
      @raw_data     = data
      @api_instance = instance
      @name         = data["name"]
      @type         = data["type"]
      @id           = data["id"]
      @display_name = data["displayName"]
      @self_uri     = data.dig("resources","self","ref")
      @parent_uri   = data.has_key?('parent_uri') ? data["parent"] : nil
      @subject      = data["subject"]
      @html_uri     = data.dig("resources","html","ref")
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

    def resolve_content_class(type)
      class_name = type.capitalize
      begin
        object_class = Jive.const_get class_name
      rescue NameError
        object_class = Object.const_set(class_name, Class.new(self.class))
      end
    end

    def init_content_class(item)
      resolve_content_class(item['type']).new(@api_instance, item)
    end
  end
end
