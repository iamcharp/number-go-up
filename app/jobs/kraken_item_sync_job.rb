class KrakenItemSyncJob < ApplicationJob
  queue_as :default

  def perform(kraken_item)
    Rails.logger.info "Starting Kraken sync for item #{kraken_item.id} (#{kraken_item.name})"
    
    # Use the syncer to perform the actual sync
    syncer = KrakenItem::Syncer.new(kraken_item)
    success = syncer.sync
    
    if success
      Rails.logger.info "Kraken sync completed successfully for item #{kraken_item.id}"
    else
      Rails.logger.error "Kraken sync failed for item #{kraken_item.id}"
    end
    
    success
  end
end