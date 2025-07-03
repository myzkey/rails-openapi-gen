json.current_user do
  json.partial! 'users/user', user: @current_user
  json.permissions @current_user.permissions.pluck(:name)
end

json.stats do
  json.users_total @stats[:users_total]
  json.users_active @stats[:users_active]
  json.posts_total @stats[:posts_total]
  json.posts_today @stats[:posts_today]
end

json.top_users @top_users do |user|
  json.partial! 'users/user_with_posts', user: user
  json.engagement_score user.engagement_score
end

json.latest_posts @latest_posts do |post|
  json.partial! 'posts/post', post: post

  json.author do
    json.partial! 'users/user', user: post.author
  end

  json.recent_comments post.recent_comments.limit(3) do |comment|
    json.id comment.id
    json.content comment.content
    json.created_at comment.created_at.iso8601
    json.author do
      json.partial! 'users/user', user: comment.author
    end
  end
end

json.notifications @notifications do |notification|
  json.id notification.id
  json.title notification.title
  json.message notification.message
  json.type notification.type
  json.created_at notification.created_at.iso8601
  json.read notification.read?
end