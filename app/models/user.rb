class User < ApplicationRecord
  LOCKOUT_THRESHOLD = 5
  LOCKOUT_DURATION = 30.minutes

  has_secure_password

  has_many :access_tokens, dependent: :destroy

  validates :first_name, :last_name, :username, :email, presence: true
  validates :email, :username, uniqueness: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }

  before_validation :normalize_identity

  # Look a user up by email or username (both stored lower-cased).
  def self.find_by_identifier(identifier)
    value = identifier.to_s.strip.downcase
    return nil if value.blank?

    value.match?(URI::MailTo::EMAIL_REGEXP) ? find_by(email: value) : find_by(username: value)
  end

  def display_name
    preferred_name.presence || first_name
  end

  def full_name
    "#{first_name} #{last_name}".strip
  end

  def locked?
    return false if locked_at.nil?
    return false if lock_expired?

    true
  end

  def register_failed_login!
    attempts = (failed_login_attempts || 0) + 1

    if attempts >= LOCKOUT_THRESHOLD
      update!(failed_login_attempts: attempts, locked_at: Time.current)
    else
      update!(failed_login_attempts: attempts)
    end
  end

  def unlock_if_expired!
    return unless lock_expired?

    update!(locked_at: nil, failed_login_attempts: 0)
  end

  def reset_failed_logins!
    return if failed_login_attempts.to_i.zero?

    update!(failed_login_attempts: 0)
  end

  def lock_expired?
    locked_at.present? && locked_at <= LOCKOUT_DURATION.ago
  end

  private

  def normalize_identity
    self.email = email.to_s.strip.downcase.presence
    self.username = username.to_s.strip.downcase.presence
  end
end
