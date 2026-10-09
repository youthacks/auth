allowed_domains_path = Rails.root.join("config", "allowed_domains.txt")
allowed_domains = if File.exist?(allowed_domains_path)
  File.read(allowed_domains_path).lines.map(&:strip).reject(&:empty?)
else
  []
end

Rails.configuration.x.allowed_domains = allowed_domains
