jive-ruby
=========

A Ruby Interface to the Jive REST API (https://developers.jivesoftware.com/api/rest).

Apologies, but the documentation is low down on my list of priorities for the project I am working on at the moment. This code is messy and could do with some refactoring. There are bugs and it's a work in progress.

To get going:

    require 'jive_api'
    j = Jive::Api '<username>', '<password>', '<uri of your jive server>'
    me = j.person_by_username '<username>'
    puts me.display_name

Example
-------

There is some code in the /examples directory. 

### content-csv.rb

Creates a CSV file called output.csv with the author, type, update time, "path" (where in Jive the content is located) and name. 

Run it with;

    ruby ./content-csv.rb <username> <password> <url>

Where URL is http://_servername_
