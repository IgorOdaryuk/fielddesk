class OutboundMessagePolicy < ApplicationPolicy
  def index? = staff?
end
