class AddPayloadToEmailVerifications < ActiveRecord::Migration[8.0]
  def change
    add_column :email_verifications, :payload, :jsonb, null: false, default: {}
  end
end
