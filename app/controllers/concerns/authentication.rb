# Cookie-backed sessions. The browser holds an encrypted cookie containing a
# random token; the SHA-256 digest of that token is stored in `access_tokens`
# so sessions can be revoked server-side.
module Authentication
  extend ActiveSupport::Concern

  ACCESS_TOKEN_COOKIE = :idp_access_token

  included do
    helper_method :current_user, :signed_in?
  end

  private

  def current_user
    return @current_user if defined?(@current_user)

    @current_user = find_user_from_cookie
  end

  def signed_in?
    current_user.present?
  end

  def require_user!
    return if signed_in?

    redirect_to login_path(return_to: request.fullpath), alert: "Please sign in to continue."
  end

  def sign_in(user)
    user.update!(last_login_at: Time.current)
    raw_token = AccessToken.issue_for(user, request)
    cookies.encrypted[ACCESS_TOKEN_COOKIE] = access_token_cookie_options.merge(value: raw_token)
    @current_user = user
  end

  def sign_out
    raw_token = cookies.encrypted[ACCESS_TOKEN_COOKIE].to_s
    if raw_token.present?
      AccessToken.active.find_by(token_digest: AccessToken.digest(raw_token))&.revoke!
    end
    cookies.delete(ACCESS_TOKEN_COOKIE, access_token_cookie_options.except(:expires))
    reset_session
    @current_user = nil
  end

  def find_user_from_cookie
    raw_token = cookies.encrypted[ACCESS_TOKEN_COOKIE].to_s
    return nil if raw_token.blank?

    token_record = AccessToken.active.find_by(token_digest: AccessToken.digest(raw_token))
    return nil if token_record.nil?

    token_record.touch(:last_used_at)
    token_record.user
  end

  def access_token_cookie_options
    {
      http_only: true,
      secure: Rails.env.production?,
      same_site: :lax,
      expires: AccessToken::TTL.from_now
    }
  end
end
