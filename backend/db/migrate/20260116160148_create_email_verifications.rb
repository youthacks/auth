class CreateEmailVerifications < ActiveRecord::Migration[8.0]
  def change
    create_table :email_verifications do |t|
      t.string :email, null: false
      t.string :code_digest, null: false
      t.datetime :expires_at, null: false
      t.datetime :used_at
      t.jsonb :payload, null: false, default: {}

      t.timestamps
    end

    add_index :email_verifications, :email
    add_index :email_verifications, :expires_at
    add_index :email_verifications, :used_at
  end
end
