class PostsController < ApplicationController
  def index
    @posts = Post.order(created_at: :desc)
    @post = Post.new
  end

  def show
    @post = Post.find(params[:id])
  end

  def create
    @post = Post.new(post_params)

    if @post.save
      redirect_to root_path, notice: "Post created."
    else
      @posts = Post.order(created_at: :desc)
      render :index, status: :unprocessable_entity
    end
  end

  def destroy
    Post.find(params[:id]).destroy
    redirect_to root_path, notice: "Post deleted."
  end

  private

  def post_params
    params.require(:post).permit(:title, :body)
  end
end
