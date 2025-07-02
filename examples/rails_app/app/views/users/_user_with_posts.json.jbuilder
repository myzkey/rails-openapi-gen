# Partial that includes user info and their posts
# This shows how partials can include other partials

# Basic user info
json.partial! 'users/user', user: user

# User's posts
json.posts user.posts do |post|
  json.partial! 'posts/post', post: post
end

# @openapi posts_count:integer description:"Number of posts by this user"
json.posts_count user.posts.count