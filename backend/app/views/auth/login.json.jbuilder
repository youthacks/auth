json.user do
  json.id @user.id
  json.first_name @user.first_name
  json.last_name @user.last_name
  json.preferred_name @user.preferred_name
  json.username @user.username
  json.email @user.email
end
json.refresh_token @refresh_token
json.message @message
