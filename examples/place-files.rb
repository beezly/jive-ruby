require 'rubygems'
require 'jive_api'
require 'mime/types'
require 'tempfile'

# Add some common missing MIME Types

MIME::Types.add MIME::Type.from_array("application/vnd.openxmlformats-officedocument.presentationml", ['pptx'])
MIME::Types.add MIME::Type.from_array("application/vnd.openxmlformats-officedocument.wordprocessingml", ['docx'])
MIME::Types.add MIME::Type.from_array("application/vnd.openxmlformats-officedocument.spreadsheetml", ['xlsx'])
MIME::Types.add MIME::Type.from_array("application/vnd.ms-word", ['doc'])

def content_from_space space, sub_spaces = false, path = "."
  tr_display_name=space.display_name.tr '/\\', ''
  space_path = File.join path, tr_display_name
  Dir::mkdir space_path
  space.content.each do |content|
    tr_subject = content.subject.tr '/\\', ''
    case content.type
      
    when "file"
      file_content=content.get
      unless tr_subject.match /\.[a-zA-Z0-9]{1,4}$/
        # Append a default extension for the files mime type
        puts "Server claims document is MIME Type: #{content.mime_type}"
        if (MIME::Types[content.mime_type]) and (MIME::Types[content.mime_type].first.extensions)
          tr_subject = "#{tr_subject}.#{MIME::Types[content.mime_type].first.extensions[0]}"
          puts "Appending #{MIME::Types[content.mime_type].first.extensions[0]} to #{content.subject} based upon MIME Type: #{content.mime_type}"
        end
      end
      puts "Creating #{File.join(space_path, tr_subject)}"   
      File.open(File.join(space_path, tr_subject), "wb") { |file| file.write(file_content) }

    when "document"
      puts "Creating #{File.join(space_path, tr_subject)}.html"
      File.open(File.join(space_path, "#{tr_subject}.html"), "wb") { |file| file.write(content.get) }

    when "discussion"
      subject = content.subject
      body = content.get
      author = content.author.display_name
      messages = content.messages
      messages_html = messages.map { |message| "<div class='message-author'>#{message.author.display_name}</div><div class='message-content'>#{message.get}</div>" }.join
      body_html = "<h1>#{subject}</h1><h2>#{author}</h2><div class='message-body'>#{body}</div><div class='messages'>#{messages_html}</div>"
      filename = "discussion:#{subject.tr('/\\?,.[]', '').tr(' ','_')}.html"
      puts "Creating Discussion for #{subject} in #{filename}"
      File.open(File.join(space_path, filename), "wb") { |file| file.write(body_html) }
      
    else 
      puts "Did Nothing with #{content.class} #{content.subject} yet"
    end
    
  end
  
  space.places do |place|
    puts "#{place.type} - #{place.name}"
  end
  
  space.sub_spaces.each {|sub_space| content_from_space sub_space, sub_spaces, space_path } if sub_spaces
end
