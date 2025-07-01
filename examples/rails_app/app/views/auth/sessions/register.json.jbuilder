# @openapi_operation summary:"User registration" tags:[Authentication,Public] description:"Register a new user account" responseDescription:"New user object details"

# @openapi id:integer required:true description:"New user ID"
json.id @user[:id]

# @openapi email:string required:true description:"User email address"
json.email @user[:email]

# @openapi name:string required:true description:"User full name"
json.name @user[:name]

# @openapi created_at:string required:true description:"Account creation timestamp"
json.created_at @user[:created_at].iso8601

# @openapi message:string description:"Success message"
json.message "User registered successfully"