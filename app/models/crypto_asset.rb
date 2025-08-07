class CryptoAsset < ApplicationRecord
  validates :symbol, :name, :exchange_name, presence: true
  validates :symbol, uniqueness: { scope: :exchange_name }
  validates :decimals, presence: true, numericality: { greater_than_or_equal_to: 0 }

  has_many :crypto_prices, dependent: :destroy

  scope :by_exchange, ->(exchange) { where(exchange_name: exchange) }
  scope :tradeable, -> { where(can_deposit: true, can_withdraw: true) }

  # Get the latest price for this asset in the specified currency
  def latest_price(currency = "USD")
    crypto_prices.where(currency: currency)
                 .order(date: :desc)
                 .first
                 &.price || 0.0
  end

  # Get price for a specific date
  def price_on_date(date, currency = "USD")
    crypto_prices.where(currency: currency, date: date)
                 .first
                 &.price || 0.0
  end

  # Update price for a specific date
  def update_price(price, date = Date.current, currency = "USD")
    crypto_price = crypto_prices.find_or_initialize_by(
      date: date,
      currency: currency
    )
    crypto_price.price = price
    crypto_price.save!
  end

  # Check if this asset is supported by Kraken
  def kraken_supported?
    exchange_name == "Kraken"
  end

  def display_name
    "#{name} (#{symbol})"
  end
end
