class KrakenAccount < ApplicationRecord
  belongs_to :kraken_item
  has_one :account, dependent: :destroy
  has_one :family, through: :kraken_item

  validates :kraken_id, :name, :asset_symbol, :currency, presence: true
  validates :kraken_id, uniqueness: true

  scope :active, -> { joins(:account).where(accounts: { active: true }) }
  scope :with_balance, -> { where("balance > ?", 0) }

  def balance_money
    Money.new(usd_value, currency) if usd_value.present?
  end

  def quantity_display
    # Format quantity with appropriate decimals based on asset
    case asset_symbol
    when "BTC", "ETH"
      "%.8f" % balance
    when "USD", "EUR", "USDC", "USDT"
      "%.2f" % balance
    else
      "%.6f" % balance
    end
  end

  def create_account!
    return account if account.present?

    account_attrs = {
      family: family,
      name: name,
      balance: usd_value || 0,
      currency: currency,
      subtype: "crypto",
      accountable_type: "Crypto",
      accountable_attributes: {
        exchange_name: "Kraken"
      },
      kraken_account: self
    }

    self.account = Account.create!(account_attrs)
  end

  def sync_balance!
    return unless account.present?

    # Update account balance with latest USD value
    account.update!(
      balance: usd_value || 0,
      updated_at: Time.current
    )
  end

  def update_price_and_value!
    return if balance.zero?

    # Fetch current price from Kraken
    price_response = kraken_item.provider.fetch_asset_price(
      asset: asset_symbol,
      currency: currency
    )

    if price_response.success?
      self.last_price = price_response.data
      self.usd_value = balance * last_price
      save!
    else
      Rails.logger.error "Failed to update price for #{asset_symbol}: #{price_response.error}"
    end
  rescue => e
    Rails.logger.error "Error updating price for #{asset_symbol}: #{e.message}"
  end

  # Get the associated CryptoAsset if exists
  def crypto_asset
    @crypto_asset ||= CryptoAsset.find_by(
      symbol: asset_symbol,
      exchange_name: "Kraken"
    )
  end

  # Display info for the asset
  def asset_display_name
    crypto_asset&.name || asset_name || asset_symbol
  end

  def icon
    # Later we can add specific icons per crypto
    "bitcoin"
  end
end