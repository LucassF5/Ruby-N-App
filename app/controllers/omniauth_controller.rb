class OmniauthController < ApplicationController
  allow_unauthenticated_access only: %i[ apple failure ]
  skip_forgery_protection only: :apple

  def apple
    auth = request.env["omniauth.auth"]

    user = User.find_by(provider: auth.provider, uid: auth.uid)
    user ||= find_and_link_by_email(auth)
    user ||= create_from_apple(auth)

    start_new_session_for user
    redirect_to after_authentication_url
  rescue ActiveRecord::RecordInvalid => e
    raise unless e.record.errors.of_kind?(:email_address, :taken)
    redirect_to new_session_path, alert: "Já existe uma conta com esse email. Faça login com email e senha."
  end

  def failure
    redirect_to new_session_path, alert: "Não foi possível autenticar com Apple."
  end

  private
    def find_and_link_by_email(auth)
      return nil if auth.info.email.blank?
      return nil unless auth.info.email_verified

      user = User.find_by(email_address: auth.info.email)
      user&.update!(provider: auth.provider, uid: auth.uid)
      user
    end

    def create_from_apple(auth)
      User.create!(
        name: auth.info.name.presence || auth.info.email,
        email_address: auth.info.email,
        password_digest: BCrypt::Password.create(SecureRandom.hex(20)),
        provider: auth.provider,
        uid: auth.uid
      )
    end
end
