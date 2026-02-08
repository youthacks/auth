if defined?(Dotenv)
  env_file = ".env"
  env_file = ".env.production" if Rails.env.production?

  Dotenv.load(Rails.root.join(env_file))
end
