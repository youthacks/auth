require "digest"

class EmailVerification < ApplicationRecord
  TTL = 10.minutes
  MAX_ATTEMPTS = 5
  MAX_SENDS_PER_WINDOW = 10
  SEND_WINDOW = 10.minutes
  MIN_SEND_INTERVAL = 10.seconds

  validates :email, :code_digest, :expires_at, :payload, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }

  scope :active, -> { where(used_at: nil).where(arel_table[:expires_at].gt(Time.current)) }

  def self.issue_for(email, payload)
    normalized = normalize_email(email)
    raw_code = format("%06d", SecureRandom.random_number(1_000_000))
    record = nil
    now = Time.current

    transaction do
      record = where(email: normalized).order(created_at: :desc).first

      if record
        window_start = record.sent_window_started_at || record.created_at || now
        if window_start <= SEND_WINDOW.ago
          window_start = now
          sent_count = 0
        else
          sent_count = record.sent_count.to_i
        end

        # if record.last_sent_at.present? && record.last_sent_at > MIN_SEND_INTERVAL.ago
        #   return :rate_limited
        # end

        # if sent_count >= MAX_SENDS_PER_WINDOW
        #   return :rate_limited
        # end

        record.update!(
          code_digest: digest(raw_code),
          expires_at: TTL.from_now,
          payload: payload,
          used_at: nil,
          failed_attempts: 0,
          last_sent_at: now,
          sent_window_started_at: window_start,
          sent_count: sent_count + 1
        )
      else
        record = create!(
          email: normalized,
          code_digest: digest(raw_code),
          expires_at: TTL.from_now,
          payload: payload,
          last_sent_at: now,
          sent_window_started_at: now,
          sent_count: 1
        )
      end
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
    return :invalid if record.nil?

    if record.failed_attempts.to_i >= MAX_ATTEMPTS
      record.update!(used_at: Time.current)
      return :too_many
    end

    unless ActiveSupport::SecurityUtils.secure_compare(record.code_digest, digest(code))
      attempts = record.failed_attempts.to_i + 1

      if attempts >= MAX_ATTEMPTS
        record.update!(failed_attempts: attempts, used_at: Time.current)
        return :too_many
      end

      record.update!(failed_attempts: attempts)
      return :invalid
    end

    record.update!(used_at: Time.current)
    :ok
  end

  def self.digest(code)
    Digest::SHA256.hexdigest(code.to_s)
  end

  def self.normalize_email(email)
    email.to_s.strip.downcase
  end
end
