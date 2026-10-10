source "https://rubygems.org"

gem "rails", "~> 8.1.4"
gem "pg", "~> 1.1"
gem "puma", ">= 5.0"

# Assets: Propshaft serves files, esbuild bundles JS, Tailwind builds CSS (both via npm).
gem "propshaft"
gem "jsbundling-rails"
gem "cssbundling-rails"
gem "turbo-rails"
gem "stimulus-rails"

gem "bcrypt", "~> 3.1.7"
gem "tzinfo-data", platforms: %i[ windows jruby ]

gem "solid_cache"
gem "solid_queue"
gem "solid_cable"

gem "bootsnap", require: false
gem "kamal", require: false
gem "thruster", require: false
gem "dotenv-rails"

gem "jwt"
gem "doorkeeper"
gem "doorkeeper-openid_connect"

group :development, :test do
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"
  gem "brakeman", require: false
  gem "bundler-audit", require: false
  gem "rubocop-rails-omakase", require: false
end

group :test do
  gem "capybara"
  gem "selenium-webdriver"
end
