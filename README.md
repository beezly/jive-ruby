[![Build Status](https://travis-ci.org/beezly/jive-ruby.png?branch=master)](https://travis-ci.org/beezly/jive-ruby)

jive-ruby
=========
A Ruby Interface to the Jive REST API (https://developers.jivesoftware.com/api/rest).

Apologies, but the documentation is low down on my list of priorities for the project I am working on at the moment. This code is messy and could do with some refactoring. There are bugs and it's a work in progress.

Simple Example:
```ruby
    require 'jive_api'
    j = Jive::Api '<username>', '<password>', '<uri of your jive server>'
    me = j.person_by_username '<username>'
    puts me.display_name
```
## Usage
-------
`Jive::API` instances have methods that can query Jive for various types of objects. `Jive::API` handles the work of pagination and marshaling the responses into Ruby objects.
### Examples:
#### Spaces
```ruby
spaces = j.spaces
spaces.class
=> Array
spaces.first.class
=> Jive::Space
space = spaces.first
space.name
=> "My Cool Space"
space.id
=> 1023
```
#### Space Contents
```ruby
contents = space.contents
contents.class
=> Array
doc = contents.first
doc.class
=> Jive::Document
doc.content_methods
=> [:get,
 :attachments,
 :has_attachments?,
 :author,
 :visibility,
 :updated_at,
 :content_id,
 :comments,
 :raw_data,
 :uri,
 :type,
 :parent,
 :id,
 :self_uri,
 :subject,
 :display_name,
 :html_uri,
 :display_path]
 doc.get
 => "<body>..."
 doc.type
 => "document"
 doc.subject
 => "Some cool document"
```
#### Caching
`Jive::API` instances can be created with different caching mechanisms. By default `Jive::API` will attempt to use Memcached running on `localhost:11211`. However, if you don't want to use Memcached you can create an instance using in-memory hashing:
```ruby
j = Jive::Api.new("user","password","url", Jive::Cache::Hashcache)
```

Examples
-------

There is some code in the /examples directory. 

### content-csv.rb

Creates a CSV file called output.csv with the author, type, update time, "path" (where in Jive the content is located) and name. 

Run it with;

    ruby ./content-csv.rb <username> <password> <url>

Where URL is http://_servername_
