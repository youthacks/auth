class CreateSamlConsents < ActiveRecord::Migration[8.0]
  def change
    create_table :saml_consents do |t|
      t.references :user, null: false, foreign_key: true
      t.string :issuer, null: false
      t.datetime :granted_at, null: false
      t.datetime :last_used_at

      t.timestamps
    end

    add_index :saml_consents, [:user_id, :issuer], unique: true
  end
end
