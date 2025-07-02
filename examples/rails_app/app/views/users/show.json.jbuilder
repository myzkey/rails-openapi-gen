# @openapi_operation summary:"Get user details" tags:[Users] description:"Returns detailed information about a specific user"

# Use partial for basic user info
json.partial! 'users/user', user: @user

# @openapi role:string enum:[admin,moderator,user] description:"User role in the system"
json.role @user.role

# Example of nested object
json.profile do
  # @openapi bio:string description:"User biography"
  json.bio @user.profile.bio
  
  # @openapi avatar_url:string description:"URL to user's avatar image"
  json.avatar_url @user.profile.avatar_url
  
  # @openapi verified:boolean description:"Whether the user's email is verified"
  json.verified @user.profile.verified
end

# Example of array with objects
json.posts @user[:posts] || [] do |post|
  # @openapi id:integer description:"Post ID"
  json.id post[:id]
  
  # @openapi title:string description:"Post title"
  json.title post[:title]
  
  # @openapi published:boolean description:"Publication status"
  json.published post[:published]
end

# Example of metadata object
json.metadata do
  # @openapi last_login:string description:"Last login timestamp"
  json.last_login Time.current.iso8601
  
  # @openapi login_count:integer description:"Total login count"
  json.login_count 42
  
  # @openapi account_type:string enum:[free,premium,enterprise] description:"Account tier"
  json.account_type "premium"
end