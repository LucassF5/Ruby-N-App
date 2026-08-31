require "test_helper"

class PostsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @post = posts(:one)
  end

  test "should get index" do
    get root_url
    assert_response :success
  end

  test "should get show" do
    get post_url(@post)
    assert_response :success
    assert_select "h1", @post.title
  end

  test "should create post" do
    assert_difference("Post.count") do
      post posts_url, params: { post: { title: "New post", body: "Some body" } }
    end

    assert_redirected_to root_url
  end

  test "should not create post without title" do
    assert_no_difference("Post.count") do
      post posts_url, params: { post: { title: "", body: "Some body" } }
    end

    assert_response :unprocessable_entity
  end

  test "should destroy post" do
    assert_difference("Post.count", -1) do
      delete post_url(@post)
    end

    assert_redirected_to root_url
  end
end
