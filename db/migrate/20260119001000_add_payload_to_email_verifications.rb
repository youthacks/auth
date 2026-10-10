class AddPayloadToEmailVerifications < ActiveRecord::Migration[8.0]
  def change
    return if column_exists?(:email_verifications, :payload)

    add_column :email_verifications, :payload, :jsonb, null: false, default: {}
  end
end
