module Provider::CryptoConcept
  extend ActiveSupport::Concern

  # Data structures for crypto exchange operations
  Balance = Data.define(:asset, :balance, :available, :locked)
  Transaction = Data.define(:id, :type, :asset, :amount, :fee, :timestamp, :description)
  Trade = Data.define(:id, :pair, :type, :side, :amount, :price, :fee, :timestamp, :status)
  CryptoAsset = Data.define(:symbol, :name, :decimals, :can_deposit, :can_withdraw)

  # Account balance operations
  def fetch_account_balances
    raise NotImplementedError, "Subclasses must implement #fetch_account_balances"
  end

  def fetch_asset_balance(asset:)
    raise NotImplementedError, "Subclasses must implement #fetch_asset_balance"
  end

  # Transaction history operations
  def fetch_transaction_history(asset: nil, start_date: nil, end_date: nil)
    raise NotImplementedError, "Subclasses must implement #fetch_transaction_history"
  end

  def fetch_trade_history(pair: nil, start_date: nil, end_date: nil)
    raise NotImplementedError, "Subclasses must implement #fetch_trade_history"
  end

  # Asset information operations
  def fetch_supported_assets
    raise NotImplementedError, "Subclasses must implement #fetch_supported_assets"
  end

  def fetch_asset_info(asset:)
    raise NotImplementedError, "Subclasses must implement #fetch_asset_info"
  end

  # Market data operations
  def fetch_asset_price(asset:, currency: "USD")
    raise NotImplementedError, "Subclasses must implement #fetch_asset_price"
  end

  def fetch_trading_pairs
    raise NotImplementedError, "Subclasses must implement #fetch_trading_pairs"
  end
end
