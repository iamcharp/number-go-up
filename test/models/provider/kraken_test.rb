require "test_helper"

class Provider::KrakenTest < ActiveSupport::TestCase
  setup do
    @provider = Provider::Kraken.new("test-api-key", "test-private-key")
  end

  test "should initialize with api credentials" do
    assert_equal "test-api-key", @provider.send(:api_key)
    assert_equal "test-private-key", @provider.send(:private_key)
  end

  test "should generate valid nonce" do
    nonce1 = @provider.send(:generate_nonce)
    sleep(0.01)
    nonce2 = @provider.send(:generate_nonce)

    assert nonce1.to_i < nonce2.to_i
    assert nonce1.to_s.length >= 13 # Unix timestamp in milliseconds
  end

  test "should normalize bitcoin symbol" do
    assert_equal "BTC", @provider.send(:normalize_asset_symbol, "XXBT")
    assert_equal "BTC", @provider.send(:normalize_asset_symbol, "BTC")
  end

  test "should normalize ethereum symbol" do
    assert_equal "ETH", @provider.send(:normalize_asset_symbol, "XETH")
    assert_equal "ETH", @provider.send(:normalize_asset_symbol, "ETH")
  end

  test "should normalize fiat symbols" do
    assert_equal "USD", @provider.send(:normalize_asset_symbol, "ZUSD")
    assert_equal "EUR", @provider.send(:normalize_asset_symbol, "ZEUR")
  end

  test "should convert to kraken asset symbols" do
    assert_equal "XXBT", @provider.send(:kraken_asset_symbol, "BTC")
    assert_equal "XETH", @provider.send(:kraken_asset_symbol, "ETH")
    assert_equal "ZUSD", @provider.send(:kraken_asset_symbol, "USD")
    assert_equal "ZEUR", @provider.send(:kraken_asset_symbol, "EUR")
  end

  test "should normalize trading pairs" do
    assert_equal "BTC/USD", @provider.send(:normalize_trading_pair, "XXBTZUSD")
    # Fallback for unknown pairs
    assert_equal "CUSTOMTOKEN", @provider.send(:normalize_trading_pair, "CUSTOMTOKEN")
  end

  test "should use default kraken api url" do
    assert_equal "https://api.kraken.com", @provider.send(:base_url)
  end

  test "should use custom kraken api url from env" do
    original_url = ENV["KRAKEN_API_URL"]
    ENV["KRAKEN_API_URL"] = "https://custom.kraken.api"

    provider = Provider::Kraken.new("key", "secret")
    assert_equal "https://custom.kraken.api", provider.send(:base_url)
  ensure
    ENV["KRAKEN_API_URL"] = original_url
  end

  test "should generate signature for authentication" do
    url = "/0/private/Balance"
    post_data = "nonce=1234567890"
    nonce = "1234567890"

    signature = @provider.send(:generate_signature, url, post_data, nonce)

    # Should generate a base64 encoded string
    assert signature.is_a?(String)
    assert signature.length > 0

    # Should be valid base64
    assert_nothing_raised do
      Base64.decode64(signature)
    end
  end
end
