require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Fielddesk
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    config.time_zone = "Eastern Time (US & Canada)"

    # structure.sql, not schema.rb: the job number sequence must survive a dump.
    config.active_record.schema_format = :sql

    # Customer phone and email are encrypted at rest. Deterministic encryption
    # keeps them searchable by exact match. Production keys come from ENV only;
    # the fallbacks below are public and exist so dev/test boot without setup.
    config.active_record.encryption.primary_key =
      ENV.fetch("AR_ENCRYPTION_PRIMARY_KEY", "dev-only-primary-key-not-secret-000")
    config.active_record.encryption.deterministic_key =
      ENV.fetch("AR_ENCRYPTION_DETERMINISTIC_KEY", "dev-only-deterministic-key-not-secret")
    config.active_record.encryption.key_derivation_salt =
      ENV.fetch("AR_ENCRYPTION_KEY_DERIVATION_SALT", "dev-only-derivation-salt-not-secret")
  end
end
