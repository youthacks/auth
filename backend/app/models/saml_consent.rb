class SamlConsent < ApplicationRecord
  belongs_to :user

  validates :issuer, presence: true
end
