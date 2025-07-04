# @openapi_operation summary:"Get user details" description:"Returns detailed information about a specific user" tags:[Users]
json.partial! 'users/user', user: @user

# @openapi role:string description:"User role in the system" enum:[admin,moderator,user]
json.role @user.role

if @user.admin?
  # @openapi admin_notes:string description:"Admin-only notes about the user"
  json.admin_notes @user.admin_notes
end

if @user.profile.present?
  # @openapi profile:object description:"User profile information (only present if profile exists)"
  json.profile do
    # @openapi bio:string description:"User biography"
    json.bio @user.profile.bio

    # @openapi avatar_url:string description:"URL to user's avatar image"
    json.avatar_url @user.profile.avatar_url

    # @openapi verified:boolean description:"Whether the user's email is verified"
    json.verified @user.profile.verified
  end
end

# @openapi posts:array items:object
json.posts @user[:posts] || [] do |post|
  # @openapi id:integer description:"Post ID"
  json.id post[:id]
  # @openapi title:string description:"Post title"
  json.title post[:title]
  # @openapi published:boolean description:"Publication status"
  json.published post[:published]
end

# @openapi metadata:object
json.metadata do
  # @openapi last_login:string description:"Last login timestamp"
  json.last_login Time.current.iso8601

  # @openapi login_count:integer description:"Total login count"
  json.login_count 42

  # @openapi account_type:string description:"Account tier" enum:[free,premium,enterprise]
  json.account_type "premium"

  if @user.premium?
    # @openapi premium_features:array items:string description:"List of premium features enabled"
    json.premium_features ["advanced_analytics", "priority_support"]
    # @openapi billing_info:object description:"Billing information for premium users"
    json.billing_info do
      # @openapi plan:string description:"Current billing plan"
      json.plan "premium_monthly"
      # @openapi next_billing_date:string description:"Next billing date"
      json.next_billing_date "2024-08-01"
    end
  end
end