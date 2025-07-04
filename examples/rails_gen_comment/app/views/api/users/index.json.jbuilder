# @openapi_operation summary:"Index User" tags:[Users]
json.array! @users, partial: 'users/user', as: :user