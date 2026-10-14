# Fills a new sandbox company in the background, then tells its open
# dashboards to refresh, so the owner watches the data arrive.
class LoadSampleDataJob < ApplicationJob
  queue_as :default

  def perform(account, admin)
    DemoData.populate(account, customers: 30, admin: admin, login_suffix: account.slug.first(24))
  ensure
    account.update_columns(sample_data_loading: false)
    Turbo::StreamsChannel.broadcast_refresh_to(account, :dispatch)
  end
end
