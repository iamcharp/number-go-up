class TinkAccount::Processor
  attr_reader :tink_account

  def initialize(tink_account)
    @tink_account = tink_account
  end

  def process
    process_account!
    process_transactions
  end

  private

    def family
      tink_account.tink_item.family
    end

    def process_account!
      TinkAccount.transaction do
        account = family.accounts.find_or_initialize_by(
          tink_account_id: tink_account.id
        )

        # Name and subtype are the only attributes a user can override for Tink accounts
        account.enrich_attributes(
          {
            name: tink_account.name,
            subtype: map_subtype(tink_account.account_type)
          },
          source: "tink"
        )

        account.assign_attributes(
          accountable: map_accountable(tink_account.account_type),
          balance: tink_account.balance || 0,
          currency: tink_account.currency,
          cash_balance: tink_account.balance || 0
        )

        account.save!

        # Create or update the current balance anchor valuation for event-sourced ledger
        account.set_current_balance(tink_account.balance || 0)
      end
    end

    def process_transactions
      TinkAccount::Transactions::Processor.new(tink_account).process
    rescue => e
      report_exception(e)
    end

    def map_subtype(account_type)
      case account_type&.upcase
      when "CHECKING"
        "checking"
      when "SAVINGS"
        "savings"
      when "CREDIT_CARD"
        "credit_card"
      when "LOAN"
        "loan"
      when "INVESTMENT"
        "investment"
      else
        "checking"
      end
    end

    def map_accountable(account_type)
      case account_type&.upcase
      when "CHECKING", "SAVINGS"
        Depository.new
      when "CREDIT_CARD"
        CreditCard.new
      when "LOAN"
        Loan.new
      when "INVESTMENT"
        Investment.new
      else
        Depository.new
      end
    end

    def report_exception(error)
      Sentry.capture_exception(error) do |scope|
        scope.set_tags(tink_account_id: tink_account.id)
      end
    end
end
