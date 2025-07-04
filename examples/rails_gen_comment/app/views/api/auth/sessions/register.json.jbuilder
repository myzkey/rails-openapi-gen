# @openapi_operation summary:"User registration" description:"Register a new user account" tags:[Authentication]
json.success true

# @openapi user:object
json.user do
  # @openapi id:integer description:"User ID"
  json.id @user[:id]
  # @openapi email:string description:"User email" format:email
  json.email @user[:email]
  # @openapi name:string description:"User name"
  json.name @user[:name]
end

# @openapi token:string description:"Authentication token"
json.token "jwt_token_here"
# @openapi expires_at:string description:"Token expiration time in ISO 8601 format" format:date-time
json.expires_at 24.hours.from_now.iso8601