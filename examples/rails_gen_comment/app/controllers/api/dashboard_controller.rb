class Api::DashboardController < ApplicationController
  def index
    @stats = {
      total_users: User.count,
      total_posts: Post.count,
      active_users: User.where(status: 'active').count
    }
    
    @recent_users = User.order(created_at: :desc).limit(5)
    @recent_posts = Post.includes(:author).order(created_at: :desc).limit(5)
    @activities = Activity.order(created_at: :desc).limit(10)
    
    respond_to do |format|
      format.json { render :index }
    end
  end
end