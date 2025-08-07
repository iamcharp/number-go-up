class CryptoPrice < ApplicationRecord
  belongs_to :crypto_asset

  validates :price, :date, :currency, presence: true
  validates :price, numericality: { greater_than_or_equal_to: 0 }
  validates :date, uniqueness: { scope: [ :crypto_asset_id, :currency ] }

  scope :recent, -> { order(date: :desc) }
  scope :for_currency, ->(currency) { where(currency: currency) }
  scope :for_date_range, ->(start_date, end_date) { where(date: start_date..end_date) }

  # Format price for display with appropriate precision
  def formatted_price
    case currency.upcase
    when "USD", "EUR", "GBP"
      "$%.2f" % price
    when "BTC"
      "₿%.8f" % price
    else
      "%.4f #{currency}" % price
    end
  end

  # Get price change compared to previous day
  def daily_change
    previous_price = crypto_asset.crypto_prices
                                .where(currency: currency)
                                .where("date < ?", date)
                                .order(date: :desc)
                                .first

    return nil unless previous_price

    {
      absolute: price - previous_price.price,
      percentage: ((price - previous_price.price) / previous_price.price * 100).round(2)
    }
  end
end
