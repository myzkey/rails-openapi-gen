json.id @user[:id]

json.email @user[:email]

json.name @user[:name]

json.created_at @user[:created_at].iso8601

json.message "User registered successfully"