require_relative "test_helper"

class TestJSON < Minitest::Test
  def test_json_strings_are_equal_despite_different_hash_insertion_order
    left = { foo: "bar" }
    left[:baz] = "qux"

    right = { baz: "qux" }
    right[:foo] = "bar"

    assert_equal Que.serialize_json(left), Que.serialize_json(right)
    assert_equal Que.serialize_json([left]), Que.serialize_json([right])
    assert_equal Que.serialize_json({ root: left }), Que.serialize_json({ root: right })
  end
end
