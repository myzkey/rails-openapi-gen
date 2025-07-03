json.partial! 'posts/post', post: @post

json.author do
  json.partial! 'users/user', user: @post.author
end

json.tags @post[:tags]

json.comments_count @post[:comments_count]

json.likes_count @post[:likes_count]

if @post[:published]
  json.published_at @post[:created_at].iso8601
end