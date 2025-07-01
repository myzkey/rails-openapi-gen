# @openapi_operation summary:"User login" tags:[Authentication,Public] description:"Authenticate user and return access token" responseDescription:"Authentication response with user details and token"

# @openapi success:boolean required:true description:"Login success status"
json.success @auth_response[:success]

# Nested user object
json.user do
  # @openapi id:integer required:true description:"User ID"
  json.id @auth_response[:user][:id]
  
  # @openapi email:string required:true description:"User email"
  json.email @auth_response[:user][:email]
  
  # @openapi name:string required:true description:"User full name"
  json.name @auth_response[:user][:name]
end

# @openapi token:string required:true description:"JWT access token"
json.token @auth_response[:token]

# @openapi expires_at:string required:true description:"Token expiration timestamp"
json.expires_at @auth_response[:expires_at].iso8601