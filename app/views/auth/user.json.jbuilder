json.user do  
    json.first_name @user.first_name
    json.last_name @user.last_name
    json.preferred_name @user.preferred_name
    json.username @user.username
    json.email @user.email
    json.admin @user.admin
  end