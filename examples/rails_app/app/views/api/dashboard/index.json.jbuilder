# @openapi_operation summary:"Get dashboard data" tags:[Dashboard] description:"Returns dashboard overview with stats and recent activities"

# @openapi total_users:integer description:"Total number of users"
json.total_users @stats[:total_users]

# @openapi total_posts:integer description:"Total number of posts"
json.total_posts @stats[:total_posts]

# @openapi active_users:integer description:"Number of active users in last 30 days"
json.active_users @stats[:active_users]

# @openapi recent_users:array description:"List of recent users"
json.recent_users @recent_users do |user|
  # @openapi id:integer description:"User ID"
  json.id user.id
  # @openapi name:string description:"User name"
  json.name user.name
  # @openapi email:string description:"User email"
  json.email user.email
end

# @openapi recent_posts:array description:"List of recent posts"
json.recent_posts @recent_posts do |post|
  # @openapi id:integer description:"Post ID"
  json.id post.id
  # @openapi title:string description:"Post title"
  json.title post.title
  # @openapi created_at:string description:"Post creation date"
  json.created_at post.created_at
end