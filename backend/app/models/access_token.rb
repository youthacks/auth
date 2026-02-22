
require "digest"

class AccessToken < ApplicationRecord
  TTL = 30.days

  belongs_to :user

  validates :token_digest, presence: true, uniqueness: true
  validates :expires_at, presence: true

  scope :active, -> { where(revoked_at: nil).where("expires_at > ?", Time.current) }

  def self.issue_for(user, request)
    raw_token = SecureRandom.hex(32)
    create!(
      user: user,
      token_digest: digest(raw_token),
      expires_at: TTL.from_now,
      user_agent: request.user_agent.to_s,
      ip_address: request.remote_ip.to_s
    )
    raw_token
  end

  def self.digest(raw_token)
    Digest::SHA256.hexdigest(raw_token.to_s)
  end

  def revoke!
    update!(revoked_at: Time.current)
  end

  def expired?
    expires_at <= Time.current
  end
end
