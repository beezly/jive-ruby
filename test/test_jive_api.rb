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
  end
end
