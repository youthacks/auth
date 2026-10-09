# Be sure to restart your server when you modify this file.

# Avoid CORS issues when API is called from the frontend app.
# Handle Cross-Origin Resource Sharing (CORS) in order to accept cross-origin Ajax requests.

# Read more: https://github.com/cyu/rack-cors

frontend_origin = (ENV["FRONTEND_URL"].presence || Rails.application.credentials.dig(:url, :frontend)).to_s
allowed_origins = []
allowed_origins << frontend_origin if frontend_origin.present?

unless Rails.env.production?
  allowed_origins << %r{\Ahttp://localhost:\d+\z}
  allowed_origins << %r{\Ahttp://127\.0\.0\.1:\d+\z}
end

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins(*allowed_origins)

    resource "*",
      headers: :any,
      methods: [ :get, :post, :put, :patch, :delete, :options, :head ],
      credentials: true
  end
end
