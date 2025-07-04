# @openapi_operation summary:"List comments" tags:[Comments,Public] description:"Returns all comments for a specific post" responseDescription:"Array of comment objects"

# @openapi root:array items:object
json.array! @comments do |comment|
  # @openapi id:integer required:true description:"Unique comment identifier"
  json.id comment[:id]

  # @openapi content:string required:true description:"Comment content"
  json.content comment[:content]

  # @openapi author:string required:true description:"Comment author name"
  json.author comment[:author]

  # @openapi created_at:string required:true description:"Comment creation timestamp"
  json.created_at comment[:created_at].iso8601

  # @openapi likes:integer description:"Number of likes on this comment"
  json.likes comment[:likes]
end