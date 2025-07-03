json.total_users @stats[:total_users]

json.total_posts @stats[:total_posts]

json.active_users @stats[:active_users]

json.recent_users @recent_users do |user|
  json.partial! 'users/user', user: user
end

json.recent_posts @recent_posts do |post|
  json.partial! 'posts/post', post: post

  json.author do
    json.partial! 'users/user', user: post.author
  end
end

json.activities @activities do |activity|
  json.id activity.id

  json.type activity.type

  json.created_at activity.created_at.iso8601

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