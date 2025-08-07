class KrakenItem < ApplicationRecord
  include Syncable

  enum :status, { good: "good", requires_update: "requires_update" }, default: :good

  # Encryption for sensitive data
  encrypts :api_key, :private_key, deterministic: false, downcase: false

  # Validations
  validates :name, :api_key, :private_key, :provider_name, presence: true

  # Associations
  belongs_to :family
  has_one_attached :logo

  has_many :kraken_accounts, dependent: :destroy
  has_many :accounts, through: :kraken_accounts

  has_many :syncs, as: :syncable, dependent: :destroy

  # Scopes
  scope :active, -> { where(scheduled_for_deletion: false) }
  scope :ordered, -> { order(created_at: :desc) }

  def provider
    @provider ||= Provider::Kraken.new(api_key, private_key)
  end

  def needs_update?
    status == "requires_update"
  end

  def process_accounts
    # Fetch all balances from Kraken
    response = provider.fetch_account_balances
    return unless response.success?

    # Process each asset balance
    response.data.each do |balance|
      # Skip assets with 0 balance unless they already have an account
      next if balance.balance.zero? && !kraken_accounts.exists?(asset_symbol: balance.asset)

      # Find or initialize the KrakenAccount
      kraken_account = kraken_accounts.find_or_initialize_by(
        kraken_id: balance.asset,
        asset_symbol: balance.asset
      )

      # Update the kraken account with latest data
      kraken_account.update!(
        name: "#{name} (#{balance.asset})",
        balance: balance.balance,
        available_balance: balance.available,
        locked_balance: balance.locked || 0.0
      )

      # Update price and USD value first
      kraken_account.update_price_and_value!
      
      # Process the account (create/update Maybe account)
      KrakenAccount::Processor.new(kraken_account).process
    end

    # Remove accounts for assets that no longer exist on Kraken
    existing_assets = response.data.map(&:asset)
    kraken_accounts.where.not(asset_symbol: existing_assets).destroy_all
  end

  def schedule_account_syncs(parent_sync: nil, window_start_date: nil, window_end_date: nil)
    accounts.each do |account|
      account.sync_later(
        parent_sync: parent_sync,
        window_start_date: window_start_date,
        window_end_date: window_end_date
      )
    end
  end

  def destroy_later
    update!(scheduled_for_deletion: true)
    DestroyJob.perform_later(self)
  end

  # Calculate total USD value across all accounts
  def total_usd_value
    kraken_accounts.sum(:usd_value)
  end

  # Check if we can connect to Kraken API
  def test_connection
    response = provider.fetch_account_balances
    response.success?
  rescue => e
    Rails.logger.error "Kraken connection test failed: #{e.message}"
    false
  end
end