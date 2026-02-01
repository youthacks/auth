class AddVerificationRateLimitFields < ActiveRecord::Migration[8.0]
  def change
    add_column :email_verifications, :last_sent_at, :datetime
    add_column :email_verifications, :sent_window_started_at, :datetime
    add_column :email_verifications, :sent_count, :integer, null: false, default: 0
  end
end
