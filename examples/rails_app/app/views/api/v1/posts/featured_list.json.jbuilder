# @openapi_operation summary:"Get featured posts" description:"Returns a list of featured posts using explicit template rendering" tags:[Posts]
json.array! @posts do |post|
  # @openapi id:integer description:"Post ID"
  json.id post[:id]
  # @openapi title:string description:"Post title"
  json.title post[:title]
  # @openapi content:string description:"Post content"
  json.content post[:content]
  # @openapi published:boolean description:"Whether the post is published"
  json.published post[:published]
  # @openapi featured:boolean description:"Whether the post is featured"
  json.featured post[:featured]
  # @openapi created_at:string format:date-time description:"Post creation timestamp"
  json.created_at post[:created_at].iso8601
  # @openapi excerpt:string description:"Post excerpt"
  json.excerpt post[:content].truncate(100)
end