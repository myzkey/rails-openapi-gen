class CommentsController < ApplicationController
  def index
    @comments = [
      {
        id: 1,
        content: "Great post!",
        author: "Alice",
        created_at: Time.current,
        likes: 5
      },
      {
        id: 2,
        content: "Thanks for sharing",
        author: "Bob", 
        created_at: 1.hour.ago,
        likes: 2
      }
    ]
  end

  def create
    # POST endpoint
    render json: { success: true, message: "Comment created successfully" }
  end
end