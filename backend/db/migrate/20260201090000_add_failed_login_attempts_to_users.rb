class AddFailedLoginAttemptsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :failed_login_attempts, :integer, null: false, default: 0
  end
end
