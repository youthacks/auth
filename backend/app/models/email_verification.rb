require "digest"

class EmailVerification < ApplicationRecord
  TTL = 10.minutes

  validates :email, :code_digest, :expires_at, :payload, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }

  scope :active, -> { where(used_at: nil).where(arel_table[:expires_at].gt(Time.current)) }

  def self.issue_for(email, payload)
    normalized = normalize_email(email)
    raw_code = format("%06d", SecureRandom.random_number(1_000_000))
    record = nil

    transaction do
      where(email: normalized).delete_all
      record = create!(
        email: normalized,
        code_digest: digest(raw_code),
        expires_at: TTL.from_now,
        payload: payload
      )
    end

    UserMailer.with(email: normalized, code: raw_code, expires_in: (TTL / 60)).verification_code.deliver_later
    record
  end

  def self.latest_for(email)
    normalized = normalize_email(email)
    where(email: normalized).order(created_at: :desc).first
  end

  def self.consume!(email, code)
    normalized = normalize_email(email)
    record = active.find_by(email: normalized)
    return false if record.nil?

    unless ActiveSupport::SecurityUtils.secure_compare(record.code_digest, digest(code))
      return false
    end

    record.update!(used_at: Time.current)
    true
  end

  def self.digest(code)
    Digest::SHA256.hexdigest(code.to_s)
  end

  def self.normalize_email(email)
    email.to_s.strip.downcase
  end
end
