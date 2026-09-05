class User < ApplicationRecord
  has_secure_password
  generates_token_for :password_reset, expires_in: 15.minutes do
    password_salt&.last(10)
  end

  has_many :sessions, dependent: :destroy
  has_many :categories, dependent: :destroy
  has_many :shifts, dependent: :destroy
  has_many :push_devices, as: :owner, class_name: "ApplicationPushDevice", dependent: :destroy
  has_one_attached :avatar

  normalizes :email_address, with: ->(email) { email.strip.downcase }

  validates :name, presence: true
  validates :email_address, presence: true, uniqueness: true
  validates :password, confirmation: true, allow_nil: true
  validates :password, length: { minimum: 8 }, allow_nil: true
  validate :avatar_is_a_valid_image

  ALLOWED_AVATAR_CONTENT_TYPES = %w[ image/png image/jpeg image/webp ].freeze
  MAX_AVATAR_SIZE = 5.megabytes

  private
    def password_salt
      password_digest
    end

    def avatar_is_a_valid_image
      return unless avatar.attached?

      unless avatar.blob.content_type.in?(ALLOWED_AVATAR_CONTENT_TYPES)
        errors.add(:avatar, "deve ser PNG, JPEG ou WebP")
      end

      if avatar.blob.byte_size > MAX_AVATAR_SIZE
        errors.add(:avatar, "deve ter no máximo 5MB")
      end
    end
end
