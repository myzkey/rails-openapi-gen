# @openapi id:integer required:true description:"User ID"
json.id user[:id]

# @openapi name:string required:true description:"User name"
json.name user[:name]

# @openapi email:string required:true description:"User email"
json.email user[:email]

# @openapi created_at:string required:true description:"User creation timestamp"
json.created_at user[:created_at].iso8601