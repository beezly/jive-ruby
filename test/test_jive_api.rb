require 'test/unit'
require 'jive_api'


class TestJiveAPI < Test::Unit::TestCase
  def setup
    @url = ENV['JIVE_URL']
    @user = ENV['JIVE_USER']
    @pass = ENV['JIVE_PASS']
    @api = Jive::Api.new @user, @pass, @url
  end

  def test_version
    assert_nothing_raised do
      @api.api_version
    end
  end

  def test_spaces
    s = @api.spaces :limit => 10
    assert_operator s.count, :>, 1
    assert( s[0].class == Jive::Space, "Returned class was not a Jive::Space" )
  end
  
  def test_groups
    g = @api.groups :limit => 10
    assert_operator g.count, :>, 1
    assert( g[0].class == Jive::Group, "Returned class was not a Jive::Group" )
  end
  
  def test_people
    p = @api.people :limit => 10
    assert_operator p.count, :>, 1
    assert( p[0].class == Jive::Person, "Returned class was not a Jive::Person" )
  end
  
  def test_find_admin_user
    admin_user = @api.person_by_username 'admin'
    assert( admin_user.class == Jive::Person, "Returned class was not a Jive::Person" )
    assert( admin_user.userid == 'admin' )
  end
end
