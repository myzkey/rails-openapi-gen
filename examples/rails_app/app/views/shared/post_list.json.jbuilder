# @openapi_operation summary:"Get archived posts" description:"Returns archived posts using shared template rendering" tags:[Posts]
# @openapi posts:array items:object description:"List of posts"
json.posts @posts do |post|
  # @openapi id:integer description:"Post ID"
  json.id post[:id]
  # @openapi title:string description:"Post title"
  json.title post[:title]
  # @openapi content:string description:"Post content"
  json.content post[:content]
  # @openapi published:boolean description:"Whether the post is published"
  json.published post[:published]
  # @openapi archived:boolean description:"Whether the post is archived"
  json.archived post[:archived] if post[:archived]
  # @openapi created_at:string format:date-time description:"Post creation timestamp"
  json.created_at post[:created_at].iso8601
  # @openapi status:string enum:[active,inactive] description:"Post status"
  json.status post[:published] ? "active" : "inactive"
end

# @openapi metadata:object description:"Response metadata"
json.metadata do
  # @openapi total:integer description:"Total number of posts"
  json.total @posts.count
  # @openapi fetched_at:string format:date-time description:"When the data was fetched"
  json.fetched_at Time.current.iso8601
  # @openapi template_used:string description:"Template used for rendering"
  json.template_used "shared/post_list"
end