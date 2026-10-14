class OutboundMessagesController < ApplicationController
  def index
    authorize OutboundMessage
    scope = OutboundMessage.includes(:customer, :job).newest_first
    scope = scope.where(kind: params[:kind]) if params[:kind].present?
    @pagy, @messages = pagy(:offset, scope, limit: 30)
  end
end
