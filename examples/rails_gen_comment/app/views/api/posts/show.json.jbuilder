# @openapi_operation summary:"Get post details" description:"Returns detailed information about a specific post" tags:[Posts]
json.partial! 'posts/post', post: @post

# @openapi author:object
json.author do
  json.partial! 'users/user', user: @post.author
end

# @openapi tags:array items:string description:"Post tags for categorization"
json.tags @post[:tags]

# @openapi comments_count:integer description:"Total number of comments"
json.comments_count @post[:comments_count]

# @openapi likes_count:integer description:"Total number of likes"
json.likes_count @post[:likes_count]

if @post[:published]
  # @openapi published_at:string description:"Publication timestamp"
  json.published_at @post[:created_at].iso8601
end