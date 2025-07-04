# @openapi_operation summary:"List comments" description:"Returns all comments for a specific post" tags:[Comments,Public]
# @openapi root:array items:object
json.array! @comments do |comment|
  # @openapi id:integer description:"Unique comment identifier"
  json.id comment[:id]

  # @openapi content:string description:"Comment content"
  json.content comment[:content]

  # @openapi author:string description:"Comment author name"
  json.author comment[:author]

  # @openapi created_at:string description:"Comment creation timestamp"
  json.created_at comment[:created_at].iso8601

  # @openapi likes:integer description:"Number of likes on this comment"
  json.likes comment[:likes]
end