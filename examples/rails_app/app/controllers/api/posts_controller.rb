class Api::PostsController < ApplicationController
  def index
    @posts = [
      { 
        id: 1, 
        title: "First Post", 
        content: "This is the first post", 
        published: true,
        created_at: Time.current,
        tags: ["ruby", "rails"]
      },
      { 
        id: 2, 
        title: "Second Post", 
        content: "This is the second post", 
        published: false,
        created_at: 1.day.ago,
        tags: ["javascript", "react"]
      }
    ]
  end

  def show
    @post = {
      id: params[:id].to_i,
      title: "Sample Post #{params[:id]}",
      content: "This is a sample post content for post #{params[:id]}",
      published: true,
      created_at: Time.current,
      updated_at: Time.current,
      author: {
        id: 1,
        name: "John Doe",
        email: "john@example.com"
      },
      tags: ["sample", "test"],
      comments_count: 5,
      likes_count: 10
    }
  end

  def create
    # POST endpoint - no view template needed for this example
    render json: { success: true, message: "Post created successfully" }
  end

  # Example of explicit template rendering
  def featured
    @posts = [
      { 
        id: 1, 
        title: "Featured Post 1", 
        content: "This is a featured post", 
        published: true,
        featured: true,
        created_at: Time.current
      }
    ]
    
    # Explicit render with template, formats, and handlers
    render template: "api/v1/posts/featured_list",
           formats: :json,
           handlers: :jbuilder
  end

  # Example of shared template rendering
  def archive
    @posts = [
      { 
        id: 10, 
        title: "Archived Post", 
        content: "This is an archived post", 
        published: false,
        archived: true,
        created_at: 1.month.ago
      }
    ]
    
    # Render shared template
    render template: "shared/post_list"
  end
end