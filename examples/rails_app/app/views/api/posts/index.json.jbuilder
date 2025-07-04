=begin
  @openapi_operation
    summary:"List all posts"
    tags:[Tag1,Tag2]
    description:"Detailed description"
    response_description:"Response description"
=end

# @openapi root:array items:object
json.array! @posts do |post|
  # @openapi id:integer required:true description:"Unique post identifier"
  json.id post[:id]

  # @openapi title:string required:true description:"Post title"
  json.title post[:title]

  # @openapi content:string required:true description:"Post content/body"
  json.content post[:content]

  # @openapi published:boolean required:true description:"Whether the post is published"
  json.published post[:published]

  # @openapi created_at:string required:true description:"Post creation timestamp in ISO 8601 format"
  json.created_at post[:created_at].iso8601

  # @openapi tags:array items:object
  json.tags @post[:tags] do |tag|
    # @openapi name:integer required:true description:"Tag unique identifier"
    json.name tag[:name]
    # @openapi color:string required:true description:"Tag color in hex format"
    json.color tag[:color]
  end

end