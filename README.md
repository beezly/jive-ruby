jive-ruby
=========

A Ruby Interface to the Jive REST API (https://developers.jivesoftware.com/api/rest).

Apologies, but the documentation is low down on my list of priorities for the project I am working on at the moment. This code is messy and could do with some refactoring. There are bugs and it's a work in progress.

To get going:

  require './base'
  j = Jive::Api '<username>', '<password>', '<uri of your jive server>'
  me = j.person_by_username '<username>'
  puts me.display_name