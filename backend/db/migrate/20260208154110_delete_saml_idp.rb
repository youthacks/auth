class DeleteSamlIdp < ActiveRecord::Migration[8.0]
  def change
    drop_table :saml_consents, if_exists: true
  end
end
