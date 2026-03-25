json.client do
  json.id @client.id
  json.name @client.name
  json.uid @client.uid
  json.redirect_uri @client.redirect_uri
  json.redirect_uris @client.redirect_uri.to_s.split(/\r?\n|\s+/).map(&:strip).reject(&:blank?)
  json.scopes @client.scopes
  json.confidential @client.confidential
  json.created_at @client.created_at
end
