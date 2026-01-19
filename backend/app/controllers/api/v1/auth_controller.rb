module Api
  module V1
    class AuthController < ApplicationController
      def signup
        user = User.new(signup_params)

        unless user.valid?
          return render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
        end

        payload = user.attributes.slice(
          "first_name",
          "last_name",
          "preferred_name",
          "username",
          "email",
          "password_digest"
        )

        EmailVerification.issue_for(user.email, payload)

        render json: {
          message: "Verification code sent"
        }, status: :created
      end

      def resend_email_verification
        email = params[:email].to_s

        if email.blank?
          return render json: { error: "Email is required" }, status: :unprocessable_entity
        end

        unless email.match?(URI::MailTo::EMAIL_REGEXP)
          return render json: { error: "Invalid email format" }, status: :unprocessable_entity
        end

        if User.exists?(email: email.strip.downcase)
          return render json: { error: "Account already verified" }, status: :unprocessable_entity
        end

        pending = EmailVerification.latest_for(email)

        if pending.nil?
          return render json: { error: "No pending signup" }, status: :not_found
        end

        EmailVerification.issue_for(email, pending.payload)
        render json: { message: "Verification code sent" }, status: :ok
      end

      def verify_email
        email = params[:email].to_s
        code = params[:email_code].to_s

        if email.blank? || code.blank?
          return render json: { error: "Email and email_code are required" }, status: :unprocessable_entity
        end

        unless email.match?(URI::MailTo::EMAIL_REGEXP)
          return render json: { error: "Invalid email format" }, status: :unprocessable_entity
        end

        pending = EmailVerification.active.find_by(email: email.strip.downcase)

        if pending.nil?
          return render json: { error: "Invalid or expired code" }, status: :unprocessable_entity
        end

        unless EmailVerification.consume!(email, code)
          return render json: { error: "Invalid or expired code" }, status: :unprocessable_entity
        end

        user = User.new(pending.payload)

        if user.save
          render json: { user: user_payload(user), message: "Account created" }, status: :created
        else
          render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def signup_params
        params.fetch(:user, params).permit(
          :first_name,
          :last_name,
          :preferred_name,
          :username,
          :email,
          :password,
          :password_confirmation
        )
      end

      def user_payload(user)
        {
          id: user.id,
          first_name: user.first_name,
          last_name: user.last_name,
          preferred_name: user.preferred_name,
          username: user.username,
          email: user.email
        }
      end
    end
  end
end
