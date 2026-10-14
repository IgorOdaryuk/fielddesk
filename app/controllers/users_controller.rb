class UsersController < ApplicationController
  before_action :set_user, only: %i[ edit update ]

  def index
    authorize User
    @users = policy_scope(User).order(:role, :name)
  end

  def new
    @user = authorize User.new(role: :technician)
  end

  def create
    @user = authorize User.new(user_params)

    if @user.save
      redirect_to users_path, notice: "#{@user.name} added. Share the password with them in person."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    attrs = user_params
    attrs = attrs.except(:password, :password_confirmation) if attrs[:password].blank?

    if @user.update(attrs)
      @user.sessions.where.not(id: Current.session.id).destroy_all if attrs.key?(:password)
      redirect_to users_path, notice: "#{@user.name} updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def toggle_active
    @user = authorize User.find(params[:id]), :deactivate?
    @user.update!(active: !@user.active?)
    @user.sessions.destroy_all unless @user.active?
    redirect_to users_path, notice: "#{@user.name} is now #{@user.active? ? 'active' : 'deactivated'}."
  end

  private
    def set_user
      @user = authorize User.find(params[:id])
    end

    def user_params
      params.expect(user: [ :name, :email_address, :phone, :role, :color, :password, :password_confirmation ])
    end
end
