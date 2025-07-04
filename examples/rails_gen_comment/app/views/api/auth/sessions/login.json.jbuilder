json.success @auth_response[:success]
json.user do
  json.id @auth_response[:user][:id]
  json.email @auth_response[:user][:email]
  json.name @auth_response[:user][:name]
end

json.token @auth_response[:token]
json.expires_at @auth_response[:expires_at].iso8601