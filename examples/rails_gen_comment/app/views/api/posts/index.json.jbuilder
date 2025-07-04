# @openapi_operation summary:"List all posts" tags:[Posts]
# @openapi root:array items:object
json.array! @posts do |post|
  # @openapi id:integer description:"Unique post identifier"
  json.id post[:id]

  # @openapi title:string description:"Post title"
  json.title post[:title]

  # @openapi content:string description:"Post content/body"
  json.content post[:content]

  # @openapi published:boolean description:"Whether the post is published"
  json.published post[:published]

  # @openapi created_at:string description:"Post creation timestamp in ISO 8601 format"
  json.created_at post[:created_at].iso8601

  # @openapi tags:array items:object
  json.tags @post[:tags] do |tag|
    # @openapi name:integer description:"Tag unique identifier"
    json.name tag[:name]
    # @openapi color:string description:"Tag color in hex format"
    json.color tag[:color]
  end

end