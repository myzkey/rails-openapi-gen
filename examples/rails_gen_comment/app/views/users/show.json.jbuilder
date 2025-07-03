json.partial! 'users/user', user: @user

json.role @user.role

if @user.admin?
  json.admin_notes @user.admin_notes
end

if @user.profile.present?
  json.profile do
    json.bio @user.profile.bio

    json.avatar_url @user.profile.avatar_url

    json.verified @user.profile.verified
  end
end

json.posts @user[:posts] || [] do |post|
  json.id post[:id]
  json.title post[:title]
  json.published post[:published]
end

json.metadata do
  json.last_login Time.current.iso8601

  json.login_count 42

  json.account_type "premium"

  if @user.premium?
    json.premium_features ["advanced_analytics", "priority_support"]
    json.billing_info do
      json.plan "premium_monthly"
      json.next_billing_date "2024-08-01"
    end
  end
end