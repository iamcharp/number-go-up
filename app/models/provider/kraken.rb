class Provider::Kraken < Provider
  include Provider::CryptoConcept

  # Subclass so errors caught in this provider are raised as Provider::Kraken::Error
  Error = Class.new(Provider::Error)
  AuthenticationError = Class.new(Error)
  InvalidResponseError = Class.new(Error)

  def initialize(api_key, private_key)
    @api_key = api_key
    @private_key = private_key
  end

  def healthy?
    with_provider_response do
      response = private_request("Balance")
      response.dig("error")&.empty? == true
    end
  end

  # ================================
  #       Crypto Concept Methods
  # ================================

  def fetch_account_balances
    with_provider_response do
      response = private_request("Balance")

      if response["error"]&.any?
        raise InvalidResponseError.new("API returned error: #{response["error"].join(", ")}")
      end

      result = response.dig("result") || {}

      result.map do |asset, balance|
        # Skip special Kraken asset types (.B, .F, .S, .M suffixes)
        next if asset.include?(".")

        Balance.new(
          asset: normalize_asset_symbol(asset),
          balance: balance.to_f,
          available: balance.to_f, # Kraken Balance endpoint returns available balance
          locked: 0.0 # Would need ExtendedBalance for hold amounts
        )
      end.compact
    end
  end

  def fetch_asset_balance(asset:)
    with_provider_response do
      balances = fetch_account_balances.data
      balances.find { |b| b.asset == asset.upcase } ||
        Balance.new(asset: asset.upcase, balance: 0.0, available: 0.0, locked: 0.0)
    end
  end

  def fetch_transaction_history(asset: nil, start_date: nil, end_date: nil)
    with_provider_response do
      params = {}
      params["start"] = start_date.to_time.to_i if start_date
      params["end"] = end_date.to_time.to_i if end_date
      params["asset"] = kraken_asset_symbol(asset) if asset

      response = private_request("Ledgers", params)

      if response["error"]&.any?
        raise InvalidResponseError.new("API returned error: #{response["error"].join(", ")}")
      end

      ledger = response.dig("result", "ledger") || {}

      ledger.map do |id, entry|
        Transaction.new(
          id: id,
          type: entry["type"],
          asset: normalize_asset_symbol(entry["asset"]),
          amount: entry["amount"].to_f,
          fee: entry["fee"].to_f,
          timestamp: Time.at(entry["time"].to_f),
          description: "#{entry["type"]} - #{entry["subtype"] || "N/A"}"
        )
      end
    end
  end

  def fetch_trade_history(pair: nil, start_date: nil, end_date: nil)
    with_provider_response do
      params = {}
      params["start"] = start_date.to_time.to_i if start_date
      params["end"] = end_date.to_time.to_i if end_date

      response = private_request("TradesHistory", params)

      if response["error"]&.any?
        raise InvalidResponseError.new("API returned error: #{response["error"].join(", ")}")
      end

      trades = response.dig("result", "trades") || {}

      trades.map do |id, trade|
        # Filter by pair if specified
        next if pair && !trade["pair"].include?(pair.upcase)

        Trade.new(
          id: id,
          pair: normalize_trading_pair(trade["pair"]),
          type: trade["ordertype"],
          side: trade["type"], # buy or sell
          amount: trade["vol"].to_f,
          price: trade["price"].to_f,
          fee: trade["fee"].to_f,
          timestamp: Time.at(trade["time"].to_f),
          status: "closed" # TradesHistory only returns closed trades
        )
      end.compact
    end
  end

  def fetch_supported_assets
    with_provider_response do
      response = public_request("Assets")

      if response["error"]&.any?
        raise InvalidResponseError.new("API returned error: #{response["error"].join(", ")}")
      end

      assets = response.dig("result") || {}

      assets.map do |symbol, info|
        # Skip special asset classes
        next if symbol.include?(".")

        CryptoAsset.new(
          symbol: normalize_asset_symbol(symbol),
          name: info["altname"],
          decimals: info["decimals"].to_i,
          can_deposit: info["status"] == "enabled",
          can_withdraw: info["status"] == "enabled"
        )
      end.compact
    end
  end

  def fetch_asset_info(asset:)
    with_provider_response do
      assets = fetch_supported_assets.data
      found_asset = assets.find { |a| a.symbol == asset.upcase }
      raise InvalidResponseError.new("Asset #{asset} not found") unless found_asset
      found_asset
    end
  end

  def fetch_asset_price(asset:, currency: "USD")
    # Special case: if asset is the same as currency, price is 1.0
    normalized_asset = normalize_asset_symbol(kraken_asset_symbol(asset))
    normalized_currency = normalize_asset_symbol(kraken_asset_symbol(currency))
    
    if normalized_asset == normalized_currency
      return Provider::Response.new(success?: true, data: 1.0, error: nil)
    end

    with_provider_response do
      # Kraken uses inconsistent pair formats, so try multiple combinations
      asset_symbol = kraken_asset_symbol(asset)
      currency_symbol = kraken_asset_symbol(currency)
      
      # Try different pair format combinations
      pairs_to_try = [
        "#{asset_symbol}#{currency.upcase}",      # e.g., USDCUSD, XDGUSD
        "#{asset_symbol}#{currency_symbol}",      # e.g., USDCZUSD, XDGZUSD
        "#{asset.upcase}#{currency.upcase}",      # e.g., USDCUSD (no transformation)
      ].uniq

      response = nil
      successful_pair = nil

      # Try each pair format until one works
      pairs_to_try.each do |pair|
        response = public_request("Ticker", { pair: pair })
        
        # If no error, we found a working pair
        if response["error"].blank? && response.dig("result").present?
          successful_pair = pair
          break
        end
      end

      # If all pairs failed, raise the error from the last attempt
      if response["error"]&.any? || response.dig("result").blank?
        error_msg = response["error"]&.join(", ") || "No ticker data available"
        raise InvalidResponseError.new("API returned error for all pair formats (tried: #{pairs_to_try.join(', ')}): #{error_msg}")
      end

      result = response.dig("result")
      return 0.0 if result.blank?

      # Kraken returns ticker data with pair as key
      ticker_data = result.values.first
      ticker_data&.dig("c", 0)&.to_f || 0.0 # "c" is last trade price
    end
  end

  def fetch_trading_pairs
    with_provider_response do
      response = public_request("AssetPairs")

      if response["error"]&.any?
        raise InvalidResponseError.new("API returned error: #{response["error"].join(", ")}")
      end

      pairs = response.dig("result") || {}

      pairs.keys.map do |pair|
        normalize_trading_pair(pair)
      end
    end
  end

  private
    attr_reader :api_key, :private_key

    def base_url
      ENV["KRAKEN_API_URL"] || "https://api.kraken.com"
    end

    def client
      @client ||= Faraday.new(url: base_url) do |faraday|
        faraday.request(:retry, {
          max: 2,
          interval: 0.05,
          interval_randomness: 0.5,
          backoff_factor: 2
        })
        faraday.response :raise_error
        faraday.headers["User-Agent"] = "Maybe Finance Kraken Integration"
      end
    end

    def public_request(method, params = {})
      url = "/0/public/#{method}"
      response = client.get(url, params)
      JSON.parse(response.body)
    end

    def private_request(method, params = {})
      url = "/0/private/#{method}"
      nonce = generate_nonce

      body_params = params.merge(nonce: nonce)
      post_data = URI.encode_www_form(body_params)

      headers = {
        "API-Key" => api_key,
        "API-Sign" => generate_signature(url, post_data, nonce)
      }

      response = client.post(url, post_data) do |req|
        req.headers.merge!(headers)
        req.headers["Content-Type"] = "application/x-www-form-urlencoded"
      end

      JSON.parse(response.body)
    end

    def generate_nonce
      (Time.now.to_f * 1000).to_i.to_s
    end

    def generate_signature(url, post_data, nonce)
      # Kraken signature algorithm:
      # HMAC-SHA512 of (URI path + SHA256(nonce + POST data)) using decoded API secret

      # Step 1: Create message to sign
      message = nonce + post_data
      sha256_hash = Digest::SHA256.digest(message)

      # Step 2: Combine URI path with SHA256 hash
      sign_message = url + sha256_hash

      # Step 3: Create HMAC using decoded private key
      decoded_secret = Base64.decode64(private_key)
      signature = OpenSSL::HMAC.digest("sha512", decoded_secret, sign_message)

      # Step 4: Encode final signature
      Base64.strict_encode64(signature)
    end

    # Normalize Kraken asset symbols to standard format
    def normalize_asset_symbol(symbol)
      case symbol
      when /^XXBT$/ then "BTC"
      when /^XETH$/ then "ETH"
      when /^ZUSD$/ then "USD"
      when /^ZEUR$/ then "EUR"
      when /^X(.+)$/ then $1
      when /^Z(.+)$/ then $1
      else symbol
      end
    end

    # Convert standard symbols to Kraken format
    def kraken_asset_symbol(symbol)
      case symbol.upcase
      when "BTC" then "XXBT"
      when "ETH" then "XETH"
      when "USD" then "ZUSD"
      when "EUR" then "ZEUR"
      else symbol.upcase
      end
    end

    # Normalize trading pairs from Kraken format
    def normalize_trading_pair(pair)
      # Remove common Kraken suffixes and normalize
      normalized = pair.gsub(/\.d$/, "") # Remove dark pool suffix

      # Try to split common pairs
      if normalized.match(/^(XXBT|XETH|XXRP|XLTC|XXLM|ADA|DOT)(.+)$/)
        base = normalize_asset_symbol($1)
        quote = normalize_asset_symbol($2)
        "#{base}/#{quote}"
      else
        # Fallback for other pairs
        normalized
      end
    end
end
