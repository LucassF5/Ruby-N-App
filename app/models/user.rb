class User < ApplicationRecord
  has_secure_password
  generates_token_for :password_reset, expires_in: 15.minutes do
    password_salt&.last(10)
  end

  has_many :sessions, dependent: :destroy

  normalizes :email_address, with: ->(email) { email.strip.downcase }

  validates :name, presence: true
  validates :email_address, presence: true, uniqueness: true

  private
    def password_salt
      password_digest
    end
end
