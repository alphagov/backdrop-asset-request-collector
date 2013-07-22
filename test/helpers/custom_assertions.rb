module CustomAssertions
  def assert_similar_time(expected, actual)
    difference = (expected - actual).abs
    assert difference < 3, "exepected #{expected} to be within 3 seconds of #{actual} but was #{difference} seconds away"
  end
end