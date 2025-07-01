# @openapi_operation summary:"List all posts" tags:[Posts,Public] description:"Returns a paginated list of all published posts" responseDescription:"Array of post objects with metadata"

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
  
  # @openapi tags:array description:"Array of tag strings associated with the post"
  json.tags post[:tags]
end