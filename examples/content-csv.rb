require 'rubygems'
require 'jive_api'
require 'csv'

# Username, Password and Server HTTP Endpoint
j = Jive::Api.new ARGV[0], ARGV[1], ARGV[2]

CSV.open("output.csv", 'w') do |csv|
  c=0
  j.contents( :query => { :count => 5 }) do |content| 
    csv << [content.author.userid, content.type, content.updated_at.strftime('%Y-%m-%d %H:%M:%S'), content.parent ? content.parent.display_path : '', content.subject ]
    csv.flush
    puts "#{content.type}, #{c=c+1}, #{j.object_cache.size}"
  end
end
