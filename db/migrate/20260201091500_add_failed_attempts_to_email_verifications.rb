class AddFailedAttemptsToEmailVerifications < ActiveRecord::Migration[8.0]
  def change
    add_column :email_verifications, :failed_attempts, :integer, null: false, default: 0
  end
end
