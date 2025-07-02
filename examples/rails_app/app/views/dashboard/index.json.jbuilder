# @openapi_operation summary:"Get dashboard data" tags:[Dashboard] description:"Returns dashboard overview with stats and recent activities"

# @openapi total_users:integer description:"Total number of users"
json.total_users @stats[:total_users]

# @openapi total_posts:integer description:"Total number of posts"
json.total_posts @stats[:total_posts]

# @openapi active_users:integer description:"Number of active users in last 30 days"
json.active_users @stats[:active_users]

# Recent users using partial
json.recent_users @recent_users do |user|
  json.partial! 'users/user', user: user
end

# Recent posts using partial
json.recent_posts @recent_posts do |post|
  json.partial! 'posts/post', post: post
  
  # Add author info to each post
  json.author do
    json.partial! 'users/user', user: post.author
  end
end

# Activity feed with mixed content types
json.activities @activities do |activity|
  # @openapi id:integer description:"Activity unique identifier"
  json.id activity.id
  
  # @openapi type:string enum:[user_created,post_published,comment_added] description:"Type of activity"
  json.type activity.type
  
  # @openapi created_at:string format:date-time description:"Activity timestamp"
  json.created_at activity.created_at.iso8601
  
  # Different content based on activity type
  case activity.type
  when 'user_created'
    json.user do
      json.partial! 'users/user', user: activity.subject
    end
  when 'post_published'
    json.post do
      json.partial! 'posts/post', post: activity.subject
    end
  end
end