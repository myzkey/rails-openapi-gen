# @openapi id:integer description:"User unique identifier"
json.id user.id

# @openapi name:string description:"User full name"
json.name user.name

# @openapi email:string description:"User email address"
json.email user.email

# @openapi status:string description:"Current user status" enum:[active,inactive,suspended]
json.status user.status

# @openapi created_at:string description:"Account creation timestamp"
json.created_at user.created_at.iso8601