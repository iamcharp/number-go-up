Rails.application.configure do
  config.tink = nil

  if ENV["TINK_CLIENT_ID"].present? && ENV["TINK_CLIENT_SECRET"].present?
    config.tink = {
      client_id: ENV["TINK_CLIENT_ID"],
      client_secret: ENV["TINK_CLIENT_SECRET"],
      environment: ENV["TINK_ENV"] || "sandbox", # "sandbox" or "production"
      base_url: ENV["TINK_BASE_URL"] || "https://api.tink.com",
      redirect_uri: ENV["TINK_REDIRECT_URI"] || "#{ENV.fetch('BASE_URL', 'http://localhost:3000')}/tink/callback"
    }
  end
end
