require "test_helper"

class PostTest < ActiveSupport::TestCase
  test "valid with title and body" do
    post = Post.new(title: "Hello", body: "World")
    assert post.valid?
  end

  test "invalid without title" do
    post = Post.new(title: nil, body: "World")
    assert_not post.valid?
  end

  test "invalid without body" do
    post = Post.new(title: "Hello", body: nil)
    assert_not post.valid?
  end
end
