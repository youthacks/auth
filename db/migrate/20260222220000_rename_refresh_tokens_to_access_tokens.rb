class RenameRefreshTokensToAccessTokens < ActiveRecord::Migration[8.0]
  def up
    rename_table :refresh_tokens, :access_tokens
  end

  def down
    rename_table :access_tokens, :refresh_tokens
  end
end
