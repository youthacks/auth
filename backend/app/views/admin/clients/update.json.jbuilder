json.message @message
json.client do
  json.id @client.id
  json.name @client.name
  json.uid @client.uid
  json.redirect_uri @client.redirect_uri
  json.scopes @client.scopes
  json.confidential @client.confidential
  json.created_at @client.created_at
end
