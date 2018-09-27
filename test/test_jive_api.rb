require 'bundler/setup'
require 'minitest/autorun'

require_relative '../lib/jive/api'

class TestJiveAPI < Minitest::Test
  def setup
    @url = ENV['JIVE_URL']
    @user = ENV['JIVE_USER']
    @pass = ENV['JIVE_PASS']
    fail "Set JIVE_URL, JIVE_USER and JIVE_PASS before running tests" unless @url && @user && @pass
    @api = Jive::Api.new @user, @pass, @url, Jive::Cache::Hashcache
  end

  def test_version
    assert_match(/\d{4}\.\d\.\d/, @api.api_version['jiveVersion'])
  end

  def test_spaces
    s = @api.spaces :limit => 10
    assert_operator s.count, :>, 0
    assert( s[0].class == Jive::Space, "Returned class was not a Jive::Space" )
  end
  
  def test_groups
    g = @api.groups :limit => 10
    assert_operator g.count, :>, 0
    assert( g[0].class == Jive::Group, "Returned class was not a Jive::Group" )
  end
  
  def test_people
    p = @api.people :limit => 10
    assert_operator p.count, :>, 0
    assert( p[0].class == Jive::Person, "Returned class was not a Jive::Person" )
  end
  
  def test_find_admin_user
    admin_user = @api.person_by_username 'admin'
    assert( admin_user.class == Jive::Person, "Returned class was not a Jive::Person" )
    assert( admin_user.userid == 'admin' )
  end

  def test_main_space
    main_space = @api.main_space
    assert( main_space.class == Jive::Space, "Main Space was not a Jive::Space")
    assert( main_space.parent.nil?, "Main Space's parent was not nil")
  end
end
