class Crypto < ApplicationRecord
  include Accountable

  # Encrypted attributes for Kraken integration
  encrypts :kraken_api_key, :kraken_private_key, deterministic: false, downcase: false
  attribute :exchange_name, :string, default: "Manual"

  # Validations for Kraken credentials
  validates :kraken_api_key, :kraken_private_key, presence: true, if: :requires_kraken_credentials?

  class << self
    def color
      "#737373"
    end

    def classification
      "asset"
    end

    def icon
      "bitcoin"
    end

    def display_name
      "Crypto"
    end
  end

  # Check if this is a Kraken-connected account
  def kraken_account?
    exchange_name == "Kraken" && kraken_api_key.present? && kraken_private_key.present?
  end

  # Helper method for validation condition
  def requires_kraken_credentials?
    exchange_name == "Kraken"
  end

  # Get Kraken provider instance if configured
  def kraken_provider
    return nil unless kraken_account?
    Provider::Kraken.new(kraken_api_key, kraken_private_key)
  end

  # Sync account balance with Kraken
  def sync_with_kraken
    return false unless kraken_account?

    begin
      response = kraken_provider.fetch_account_balances
      return false unless response.success?

      # Update account balance with total USD value
      total_usd_value = calculate_total_balance_usd(response.data)
      account.update!(balance: total_usd_value) if total_usd_value > 0

      true
    rescue => error
      Rails.logger.error "Kraken sync failed for account #{account.id}: #{error.message}"
      false
    end
  end

  # Schedule a full Kraken sync job
  def sync_with_kraken_later
    return false unless kraken_account?

    KrakenSyncJob.perform_later(self)
    true
  end

  # Manual trigger for immediate sync
  def sync_now!
    return false unless kraken_account?

    KrakenSyncJob.perform_now(self)
    true
  end

  # Get detailed balance breakdown by asset
  def asset_balances
    return [] unless kraken_account?

    begin
      response = kraken_provider.fetch_account_balances
      return [] unless response.success?

      response.data
    rescue => error
      Rails.logger.error "Failed to fetch Kraken asset balances: #{error.message}"
      []
    end
  end

  private

    # Calculate total balance in USD for all assets
    def calculate_total_balance_usd(balances)
      total = 0.0

      balances.each do |balance|
        next if balance.balance <= 0

        # Get USD price for the asset
        price_response = kraken_provider.fetch_asset_price(asset: balance.asset, currency: "USD")
        if price_response.success? && price_response.data > 0
          total += balance.balance * price_response.data
        end
      end

      total
    rescue => error
      Rails.logger.error "Failed to calculate USD balance: #{error.message}"
      0.0
    end
end
