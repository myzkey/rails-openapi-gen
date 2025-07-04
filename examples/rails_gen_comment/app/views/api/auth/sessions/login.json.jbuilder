# @openapi_operation summary:"User login" description:"Authenticate user with email and password" tags:[Authentication]
# @openapi success:boolean description:"Login success status"
json.success @auth_response[:success]
# @openapi user:object
json.user do
  # @openapi id:integer description:"User ID"
  json.id @auth_response[:user][:id]
  # @openapi email:string description:"User email" format:email
  json.email @auth_response[:user][:email]
  # @openapi name:string description:"User name"
  json.name @auth_response[:user][:name]
end

# @openapi token:string description:"Authentication token"
json.token @auth_response[:token]
# @openapi expires_at:string description:"Token expiration time in ISO 8601 format" format:date-time
json.expires_at @auth_response[:expires_at].iso8601