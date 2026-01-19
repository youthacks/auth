class User < ApplicationRecord
  has_secure_password

  has_many :refresh_tokens, dependent: :delete_all

  validates :first_name, :last_name, :username, :email, presence: true
  validates :email, :username, uniqueness: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }

  before_validation :normalize_identity

  def display_name
    preferred_name.presence || first_name
  end

  def locked?
    locked_at.present?
  end

  private

  def normalize_identity
    self.email = email.to_s.strip.downcase.presence
    self.username = username.to_s.strip.downcase.presence
  end
end
