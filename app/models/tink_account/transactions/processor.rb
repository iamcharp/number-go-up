class TinkAccount::Transactions::Processor
  attr_reader :tink_account

  def initialize(tink_account)
    @tink_account = tink_account
  end

  def process
    Rails.logger.info "Starting transaction sync for Tink account #{tink_account.id}"
    
    # Fetch transactions from Tink API
    transactions_data = tink_account.tink_item.provider.get_transactions(
      tink_account.tink_item.access_token,
      account_id: tink_account.tink_id,
      from_date: 90.days.ago.to_date,
      to_date: Date.current
    )

    Rails.logger.info "Fetched #{transactions_data.count} transactions from Tink API"

    # Process each transaction using TinkEntry::Processor
    # Each entry is processed individually to avoid locking up the DB
    transactions_data.each do |transaction_data|
      TinkEntry::Processor.new(
        transaction_data,
        tink_account: tink_account,
        category_matcher: category_matcher
      ).process
    end

    Rails.logger.info "Completed transaction sync for Tink account #{tink_account.id}"
  end

  private

    def category_matcher
      @category_matcher ||= begin
        # Bootstrap categories if none exist
        if account.family.categories.none?
          account.family.categories.bootstrap!
        end

        # For now, return a simple matcher that doesn't match anything
        # TODO: Implement proper category matching for Tink transactions
        OpenStruct.new(match: -> (category) { nil })
      end
    end

    def account
      tink_account.account
    end
end