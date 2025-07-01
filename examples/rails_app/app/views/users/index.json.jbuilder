# @openapi_operation summary:"List all users" tags:[Users,Public] description:"Returns a list of all users in the system" responseDescription:"Array of user objects with basic information"

json.array! @users do |user|
  # @openapi id:integer required:true description:"Unique user identifier"
  json.id user[:id]
  
  # @openapi email:string required:true description:"User email address"
  json.email user[:email]
  
  # @openapi name:string required:true description:"Full name of the user"
  json.name user[:name]
  
  # @openapi status:string enum:[active,inactive,suspended] description:"Current user status"
  json.status user[:status]
end