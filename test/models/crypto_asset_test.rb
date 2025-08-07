require "test_helper"

class CryptoAssetTest < ActiveSupport::TestCase
  setup do
    @crypto_asset = CryptoAsset.create!(
      symbol: "BTC",
      name: "Bitcoin",
      decimals: 8,
      can_deposit: true,
      can_withdraw: true,
      exchange_name: "Kraken"
    )
  end

  test "should create valid crypto asset" do
    assert @crypto_asset.persisted?
    assert_equal "BTC", @crypto_asset.symbol
    assert_equal "Bitcoin", @crypto_asset.name
    assert_equal 8, @crypto_asset.decimals
    assert @crypto_asset.can_deposit
    assert @crypto_asset.can_withdraw
    assert_equal "Kraken", @crypto_asset.exchange_name
  end

  test "should validate required fields" do
    crypto_asset = CryptoAsset.new

    refute crypto_asset.valid?
    assert_includes crypto_asset.errors[:symbol], "can't be blank"
    assert_includes crypto_asset.errors[:name], "can't be blank"
    assert_includes crypto_asset.errors[:exchange_name], "can't be blank"
  end

  test "should enforce symbol uniqueness per exchange" do
    # Same symbol on different exchange should be allowed
    other_asset = CryptoAsset.create(
      symbol: "BTC",
      name: "Bitcoin",
      decimals: 8,
      exchange_name: "Binance"
    )
    assert other_asset.valid?

    # Same symbol on same exchange should not be allowed
    duplicate_asset = CryptoAsset.new(
      symbol: "BTC",
      name: "Bitcoin Copy",
      decimals: 8,
      exchange_name: "Kraken"
    )
    refute duplicate_asset.valid?
    assert_includes duplicate_asset.errors[:symbol], "has already been taken"
  end

  test "should have display name" do
    assert_equal "Bitcoin (BTC)", @crypto_asset.display_name
  end

  test "should check if kraken supported" do
    assert @crypto_asset.kraken_supported?

    @crypto_asset.update!(exchange_name: "Binance")
    refute @crypto_asset.kraken_supported?
  end

  test "should get latest price" do
    # Create some price records
    CryptoPrice.create!(
      crypto_asset: @crypto_asset,
      price: 50000.00,
      date: 2.days.ago,
      currency: "USD"
    )
    CryptoPrice.create!(
      crypto_asset: @crypto_asset,
      price: 52000.00,
      date: 1.day.ago,
      currency: "USD"
    )

    assert_equal 52000.00, @crypto_asset.latest_price("USD")
  end

  test "should return zero for missing price" do
    assert_equal 0.0, @crypto_asset.latest_price("USD")
  end

  test "should update price for specific date" do
    date = Date.current
    price = 51000.00

    @crypto_asset.update_price(price, date, "USD")

    crypto_price = @crypto_asset.crypto_prices.find_by(date: date, currency: "USD")
    assert_not_nil crypto_price
    assert_equal price, crypto_price.price
  end
end
