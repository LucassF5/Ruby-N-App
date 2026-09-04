class OmniauthController < ApplicationController
  allow_unauthenticated_access only: %i[ apple failure ]

  def apple
    auth = request.env["omniauth.auth"]

    user = User.find_by(provider: auth.provider, uid: auth.uid)
    user ||= find_and_link_by_email(auth)
    user ||= create_from_apple(auth)

    start_new_session_for user
    redirect_to after_authentication_url
  end

  def failure
    redirect_to new_session_path, alert: "Não foi possível autenticar com Apple."
  end

  private
    def find_and_link_by_email(auth)
      return nil if auth.info.email.blank?

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
