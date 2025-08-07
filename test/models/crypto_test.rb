require "test_helper"

class CryptoTest < ActiveSupport::TestCase
  setup do
    @family = families(:dylan_family)
    @account = @family.accounts.create!(
      name: "Test Crypto Account",
      balance: 1000,
      currency: "USD",
      accountable: Crypto.new
    )
    @crypto = @account.accountable
  end

  test "should create crypto account" do
    assert @crypto.persisted?
    assert_equal "Crypto", @crypto.class.name
    assert_equal "asset", @crypto.classification
  end

  test "should not be kraken account without credentials" do
    refute @crypto.kraken_account?
  end

  test "should be kraken account with valid credentials" do
    @crypto.update!(
      exchange_name: "Kraken",
      kraken_api_key: "test-api-key",
      kraken_private_key: "test-private-key"
    )

    assert @crypto.kraken_account?
  end

  test "should validate kraken credentials when exchange is kraken" do
    crypto = Crypto.new(
      exchange_name: "Kraken",
      kraken_api_key: "",
      kraken_private_key: ""
    )

    refute crypto.valid?
    assert_includes crypto.errors[:kraken_api_key], "can't be blank"
    assert_includes crypto.errors[:kraken_private_key], "can't be blank"
  end

  test "should not validate kraken credentials when exchange is manual" do
    @crypto.exchange_name = "Manual"
    @crypto.kraken_api_key = nil
    @crypto.kraken_private_key = nil

    assert @crypto.valid?
  end

  test "should return nil provider for non-kraken account" do
    assert_nil @crypto.kraken_provider
  end

  test "should return provider instance for kraken account" do
    @crypto.update!(
      exchange_name: "Kraken",
      kraken_api_key: "test-api-key",
      kraken_private_key: "test-private-key"
    )

    provider = @crypto.kraken_provider
    assert_instance_of Provider::Kraken, provider
  end

  test "sync_with_kraken should return false for non-kraken account" do
    refute @crypto.sync_with_kraken
  end

  test "sync_with_kraken_later should return false for non-kraken account" do
    refute @crypto.sync_with_kraken_later
  end

  test "should encrypt sensitive kraken data" do
    @crypto.update!(
      exchange_name: "Kraken",
      kraken_api_key: "test-api-key-123",
      kraken_private_key: "test-private-key-456"
    )

    # Check that the data is encrypted in the database
    raw_crypto = Crypto.find(@crypto.id)

    # The encrypted values should not be the same as the plaintext
    refute_equal "test-api-key-123", raw_crypto.read_attribute_before_type_cast(:kraken_api_key)
    refute_equal "test-private-key-456", raw_crypto.read_attribute_before_type_cast(:kraken_private_key)

    # But should decrypt properly
    assert_equal "test-api-key-123", @crypto.kraken_api_key
    assert_equal "test-private-key-456", @crypto.kraken_private_key
  end
end
