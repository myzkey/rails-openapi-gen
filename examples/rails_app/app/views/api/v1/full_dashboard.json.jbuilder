# @openapi_operation summary:"Get comprehensive dashboard" tags:[Dashboard,Admin] description:"Returns complete dashboard with all data including users, posts, and analytics"

# Current user info using partial
json.current_user do
  json.partial! 'users/user', user: @current_user
  
  # @openapi permissions:array description:"User permissions"
  json.permissions @current_user.permissions.pluck(:name)
end

# System statistics
json.stats do
  # @openapi users_total:integer description:"Total registered users"
  json.users_total @stats[:users_total]
  
  # @openapi users_active:integer description:"Active users in last 30 days"
  json.users_active @stats[:users_active]
  
  # @openapi posts_total:integer description:"Total published posts"
  json.posts_total @stats[:posts_total]
  
  # @openapi posts_today:integer description:"Posts published today"
  json.posts_today @stats[:posts_today]
end

# Top users with their posts
json.top_users @top_users do |user|
  json.partial! 'users/user_with_posts', user: user
  
  # @openapi engagement_score:number format:float description:"User engagement score"
  json.engagement_score user.engagement_score
end

# Latest posts with full details
json.latest_posts @latest_posts do |post|
  json.partial! 'posts/post', post: post
  
  # Author using partial
  json.author do
    json.partial! 'users/user', user: post.author
  end
  
  # Comments with authors
  json.recent_comments post.recent_comments.limit(3) do |comment|
    # @openapi id:integer description:"Comment ID"
    json.id comment.id
    
    # @openapi content:string description:"Comment content"
    json.content comment.content
    
    # @openapi created_at:string format:date-time description:"Comment timestamp"
    json.created_at comment.created_at.iso8601
    
    # Comment author
    json.author do
      json.partial! 'users/user', user: comment.author
    end
  end
end

# System notifications
json.notifications @notifications do |notification|
  # @openapi id:integer description:"Notification ID"
  json.id notification.id
  
  # @openapi title:string description:"Notification title"
  json.title notification.title
  
  # @openapi message:string description:"Notification message"
  json.message notification.message
  
  # @openapi type:string enum:[info,warning,error,success] description:"Notification type"
  json.type notification.type
  
  # @openapi created_at:string format:date-time description:"Notification timestamp"
  json.created_at notification.created_at.iso8601
  
  # @openapi read:boolean description:"Whether notification has been read"
  json.read notification.read?
end