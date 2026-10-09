require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module YouthacksAuth
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.0

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    config.autoload_lib(ignore: %w[assets tasks])

    config.time_zone = "UTC"

    # Public URL of this app (used for the OIDC issuer and mailer links).
    config.x.app_url = (
      ENV["APP_URL"].presence ||
      ENV["FRONTEND_URL"].presence ||
      (Rails.env.development? || Rails.env.test? ? "http://localhost:3000" : nil)
    ).to_s.delete_suffix("/")
  end
end
