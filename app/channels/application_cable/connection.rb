module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      set_current_user || reject_unauthorized_connection
    end

    private
      def set_current_user
        session = ActsAsTenant.without_tenant do
          Session.includes(:user).joins(:user).merge(User.active).find_by(id: cookies.signed[:session_id])
        end
        self.current_user = session&.user
      end
  end
end
