require 'test/unit'
require 'jive_api'

class TestJiveAPI < Test::Unit::TestCase
  def test_version
    url = ENV['JIVE_URL']
    user = ENV['JIVE_USER']
    pass = ENV['JIVE_PASS']
    api = Jive::Api.new user, pass, url
    assert_nothing_raised do
      api.api_version
    end
  end

  def test_spaces
    url = ENV['JIVE_URL']
    user = ENV['JIVE_USER']
    pass = ENV['JIVE_PASS']
    j = Jive::Api.new user, pass, url
    s = j.spaces
    assert_operator j.spaces.count, :>, 1
  end
end
