class KrakenAccount::Processor
  attr_reader :kraken_account

  def initialize(kraken_account)
    @kraken_account = kraken_account
  end

  def process
    process_account!
    update_price_and_value!
  end

  private

    def family
      kraken_account.kraken_item.family
    end

    def process_account!
      KrakenAccount.transaction do
        account = family.accounts.find_or_initialize_by(
          kraken_account_id: kraken_account.id
        )

        # Update account attributes
        account.assign_attributes(
          name: kraken_account.name,
          accountable: build_accountable,
          balance: kraken_account.usd_value || 0,
          currency: kraken_account.currency,
          cash_balance: kraken_account.usd_value || 0,
          subtype: "crypto"
        )

        account.save!

        # Set current balance for event-sourced ledger
        account.set_current_balance(kraken_account.usd_value || 0)
      end
    end

    def build_accountable
      # For KrakenAccount-based architecture, we don't need Kraken credentials
      # in the Crypto model anymore
      crypto = Crypto.new(exchange_name: "Kraken")
      
      # Skip Kraken credential validations since they're stored in KrakenItem
      crypto.skip_kraken_validation = true if crypto.respond_to?(:skip_kraken_validation=)
      
      crypto
    end

    def update_price_and_value!
      kraken_account.update_price_and_value!
    rescue => e
      report_exception(e)
    end

    def report_exception(error)
      Sentry.capture_exception(error) do |scope|
        scope.set_tags(
          kraken_account_id: kraken_account.id,
          asset_symbol: kraken_account.asset_symbol
        )
      end
    end
end