# @openapi_operation summary:"Get post details" operationId:"getPostById" tags:[Posts,Public] description:"Returns detailed information about a specific post including author and engagement metrics" responseDescription:"Single post object with complete details"

# @openapi id:integer required:true description:"Unique post identifier"
json.id @post[:id]

# @openapi title:string required:true description:"Post title"
json.title @post[:title]

# @openapi content:string required:true description:"Full post content/body"
json.content @post[:content]

# @openapi published:boolean required:true description:"Publication status"
json.published @post[:published]

# @openapi created_at:string required:true description:"Post creation timestamp"
json.created_at @post[:created_at].iso8601

# @openapi updated_at:string description:"Last update timestamp"
json.updated_at @post[:updated_at].iso8601

# Nested author object
json.author do
  # @openapi id:integer required:true description:"Author's user ID"
  json.id @post[:author][:id]
  
  # @openapi name:string required:true description:"Author's full name"
  json.name @post[:author][:name]
  
  # @openapi email:string required:true description:"Author's email address"
  json.email @post[:author][:email]
end

# @openapi tags:array description:"Post tags for categorization"
json.tags @post[:tags]

# @openapi comments_count:integer description:"Total number of comments"
json.comments_count @post[:comments_count]

# @openapi likes_count:integer description:"Total number of likes"
json.likes_count @post[:likes_count]

# Example of conditional field
if @post[:published]
  # @openapi published_at:string description:"Publication timestamp"
  json.published_at @post[:created_at].iso8601
end