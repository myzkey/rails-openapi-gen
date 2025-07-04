# @openapi id:integer description:"User unique identifier"
json.id user.id

# @openapi name:string description:"User full name"
json.name user.name

# @openapi email:string format:email description:"User email address"
json.email user.email

# @openapi status:string enum:[active,inactive,suspended] description:"Current user status"
json.status user.status

# @openapi created_at:string format:date-time description:"Account creation timestamp"
json.created_at user.created_at.iso8601