class CreateRefreshTokens < ActiveRecord::Migration[8.0]
  def change
    create_table :refresh_tokens do |t|
      t.references :user, null: false, foreign_key: true
      t.string :token_digest
      t.datetime :expires_at
      t.datetime :revoked_at
      t.datetime :last_used_at
      t.string :user_agent
      t.string :ip_address

      t.timestamps
    end
  end
end
