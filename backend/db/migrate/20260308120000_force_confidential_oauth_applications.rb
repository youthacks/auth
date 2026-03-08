class ForceConfidentialOauthApplications < ActiveRecord::Migration[8.0]
  def up
    if column_exists?(:oauth_applications, :confidential)
      execute <<~SQL
        UPDATE oauth_applications
        SET confidential = TRUE
        WHERE confidential = FALSE OR confidential IS NULL
      SQL

      change_column_default :oauth_applications, :confidential, from: nil, to: true
      change_column_null :oauth_applications, :confidential, false, true
    end
  end

  def down
    return unless column_exists?(:oauth_applications, :confidential)

    change_column_null :oauth_applications, :confidential, true
  end
end
