class TinkItem::Syncer
  attr_reader :tink_item

  def initialize(tink_item)
    @tink_item = tink_item
  end

  def perform_sync(sync)
    # Process the Tink accounts and transactions
    tink_item.process_accounts

    # All data is synced, so we can now run an account sync to calculate historical balances and more
    tink_item.schedule_account_syncs(
      parent_sync: sync,
      window_start_date: sync.window_start_date,
      window_end_date: sync.window_end_date
    )
  end

  def perform_post_sync
    # no-op
  end
end
