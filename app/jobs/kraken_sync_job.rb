class KrakenSyncJob < ApplicationJob
  queue_as :default

  def perform(crypto_account)
    return unless crypto_account.kraken_account?

    Rails.logger.info "Starting Kraken sync for account #{crypto_account.account.id}"

    begin
      # Sync supported assets first
      sync_supported_assets(crypto_account)

      # Sync account balances
      sync_account_balances(crypto_account)

      # Sync asset prices
      sync_asset_prices(crypto_account)

      # Update account total balance
      update_total_balance(crypto_account)

      Rails.logger.info "Kraken sync completed successfully for account #{crypto_account.account.id}"
    rescue => error
      Rails.logger.error "Kraken sync failed for account #{crypto_account.account.id}: #{error.message}"
      raise error
    end
  end

  private

    def sync_supported_assets(crypto_account)
      provider = crypto_account.kraken_provider
      response = provider.fetch_supported_assets

      return unless response.success?

      response.data.each do |asset_data|
        CryptoAsset.find_or_create_by(
          symbol: asset_data.symbol,
          exchange_name: "Kraken"
        ) do |crypto_asset|
          crypto_asset.name = asset_data.name
          crypto_asset.decimals = asset_data.decimals
          crypto_asset.can_deposit = asset_data.can_deposit
          crypto_asset.can_withdraw = asset_data.can_withdraw
        end
      end
    end

    def sync_account_balances(crypto_account)
      provider = crypto_account.kraken_provider
      response = provider.fetch_account_balances

      return unless response.success?

      # Store balance information in transactions/entries if needed
      # For now, we just update the main account balance
      Rails.logger.debug "Account has #{response.data.size} assets with balance"
    end

    def sync_asset_prices(crypto_account)
      provider = crypto_account.kraken_provider

      # Get all crypto assets for Kraken
      crypto_assets = CryptoAsset.by_exchange("Kraken")

      crypto_assets.find_each do |crypto_asset|
        # Skip stablecoins and fiat currencies for price fetching
        next if %w[USD EUR GBP USDT USDC].include?(crypto_asset.symbol)

        begin
          response = provider.fetch_asset_price(asset: crypto_asset.symbol, currency: "USD")

          if response.success? && response.data > 0
            crypto_asset.update_price(response.data, Date.current, "USD")
            Rails.logger.debug "Updated price for #{crypto_asset.symbol}: $#{response.data}"
          end
        rescue => error
          Rails.logger.warn "Failed to fetch price for #{crypto_asset.symbol}: #{error.message}"
          # Continue with other assets
        end
      end
    end

    def update_total_balance(crypto_account)
      success = crypto_account.sync_with_kraken

      unless success
        Rails.logger.error "Failed to update total balance for account #{crypto_account.account.id}"
      end
    end
end
