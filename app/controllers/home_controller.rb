class HomeController < ApplicationController
  def show
    skip_authorization
    redirect_to current_user.staff? ? dashboard_path : my_jobs_path
  end
end
