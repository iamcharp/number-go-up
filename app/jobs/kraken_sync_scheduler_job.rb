class KrakenSyncSchedulerJob < ApplicationJob
  queue_as :scheduled

  def perform
    Rails.logger.info "Scheduling Kraken sync jobs for all active accounts"

    # Find all active crypto accounts that are configured for Kraken
    crypto_accounts = Crypto.joins(:account)
                           .where(accounts: { status: "active" })
                           .where(exchange_name: "Kraken")
                           .where.not(kraken_api_key: [ nil, "" ])
                           .where.not(kraken_private_key: [ nil, "" ])

    if crypto_accounts.empty?
      Rails.logger.info "No active Kraken accounts found for sync"
      return
    end

    Rails.logger.info "Found #{crypto_accounts.count} active Kraken accounts to sync"

    crypto_accounts.find_each do |crypto_account|
      begin
        # Schedule sync with a small delay to avoid rate limiting
        KrakenSyncJob.set(wait: rand(1..60).seconds).perform_later(crypto_account)
        Rails.logger.debug "Scheduled sync for Kraken account #{crypto_account.account.id}"
      rescue => error
        Rails.logger.error "Failed to schedule sync for Kraken account #{crypto_account.account.id}: #{error.message}"
      end
    end

    Rails.logger.info "Completed scheduling Kraken sync jobs"
  end
end
