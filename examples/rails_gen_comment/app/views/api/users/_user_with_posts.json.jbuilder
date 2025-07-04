json.partial! 'users/user', user: user

json.posts user.posts do |post|
  json.partial! 'posts/post', post: post
end

json.posts_count user.posts.count