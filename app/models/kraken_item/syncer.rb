class KrakenItem::Syncer
  attr_reader :kraken_item, :parent_sync

  def initialize(kraken_item, parent_sync = nil)
    @kraken_item = kraken_item
    @parent_sync = parent_sync
  end

  def sync
    sync_accounts
    sync_prices
    update_account_balances
    
    true
  rescue => error
    Rails.logger.error "Kraken sync failed for item #{kraken_item.id}: #{error.message}"
    kraken_item.update!(status: "requires_update")
    false
  end

  private

    def sync_accounts
      Rails.logger.info "Syncing accounts for Kraken item #{kraken_item.id}"
      
      # Process all accounts (create/update)
      kraken_item.process_accounts
      
      Rails.logger.info "Synced #{kraken_item.kraken_accounts.count} Kraken accounts"
    end

    def sync_prices
      Rails.logger.info "Updating prices for Kraken accounts"
      
      kraken_item.kraken_accounts.each do |kraken_account|
        next if kraken_account.balance.zero?
        
        begin
          kraken_account.update_price_and_value!
        rescue => e
          Rails.logger.error "Failed to update price for #{kraken_account.asset_symbol}: #{e.message}"
          # Continue with other accounts
        end
      end
    end

    def update_account_balances
      Rails.logger.info "Updating account balances"
      
      kraken_item.kraken_accounts.each do |kraken_account|
        kraken_account.sync_balance!
      end
    end
end