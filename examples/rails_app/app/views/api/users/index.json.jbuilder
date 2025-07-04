# @openapi_operation summary:"List users" tags:[Users] description:"Returns a paginated list of users"

# Array of users using partial
json.array! @users, partial: 'users/user', as: :user