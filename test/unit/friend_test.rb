require File.dirname(__FILE__) + '/../test_helper'

class FriendTest < Test::Unit::TestCase
  fixtures :friends
  
  
  def test_friend_count
    assert_equal 1, Friend.count
  end
  
end
