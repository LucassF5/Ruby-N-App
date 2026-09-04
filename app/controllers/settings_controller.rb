class SettingsController < ApplicationController
  def edit
    @user = Current.user
  end

  def update
    @user = Current.user

    if requires_current_password? && !@user.authenticate(settings_params[:current_password])
      @user.errors.add(:current_password, "está incorreta")
      render :edit, status: :unprocessable_entity
      return
    end

    if @user.update(update_params)
      @user.sessions.where.not(id: Current.session.id).destroy_all if password_change_requested?
      redirect_to edit_settings_path, notice: "Configurações atualizadas."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private
    def settings_params
      params.require(:user).permit(:name, :email_address, :current_password, :password, :password_confirmation, :avatar)
    end

    def password_change_requested?
      settings_params[:password].present?
    end

    def email_change_requested?
      settings_params[:email_address].present? && settings_params[:email_address] != @user.email_address
    end

    def requires_current_password?
      password_change_requested? || email_change_requested?
    end

    def update_params
      attrs = settings_params.except(:current_password)
      attrs = attrs.except(:password, :password_confirmation) unless password_change_requested?
      attrs
    end
end
