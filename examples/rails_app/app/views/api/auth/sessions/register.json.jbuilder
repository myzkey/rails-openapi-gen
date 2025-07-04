# @openapi_operation summary:"User registration" tags:[Authentication,Public] description:"Register a new user account" responseDescription:"New user object details"

# @openapi id:integer required:true
json.id @user[:id]

# @openapi email:string required:true
json.email @user[:email]

# @openapi name:string required:true
json.name @user[:name]

# @openapi created_at:string required:true
json.created_at @user[:created_at].iso8601

# @openapi message:string
json.message "User registered successfully"