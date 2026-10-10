class RenameRefreshTokensToAccessTokens < ActiveRecord::Migration[8.0]
  def up
    rename_table :refresh_tokens, :access_tokens if table_exists?(:refresh_tokens) && !table_exists?(:access_tokens)
  end

  def down
    rename_table :access_tokens, :refresh_tokens if table_exists?(:access_tokens) && !table_exists?(:refresh_tokens)
  end
end
