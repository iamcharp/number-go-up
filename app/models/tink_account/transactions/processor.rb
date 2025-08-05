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

    # Process each transaction
    transactions_data.each do |transaction_data|
      process_transaction(transaction_data)
    end

    Rails.logger.info "Completed transaction sync for Tink account #{tink_account.id}"
  end

  private

    def process_transaction(transaction_data)
      Rails.logger.debug "Processing transaction: #{transaction_data['id']}"

      # Extract transaction details
      amount = extract_amount_from_tink_data(transaction_data)
      date = Date.parse(transaction_data['date'])
      description = transaction_data['description'] || transaction_data['originalDescription'] || 'Tink Transaction'
      
      # Find or create transaction
      transaction = tink_account.account.transactions.find_or_initialize_by(
        tink_transaction_id: transaction_data['id']
      )

      # Only update if this is a new transaction or if data has changed
      if transaction.new_record? || transaction_needs_update?(transaction, transaction_data)
        transaction.assign_attributes(
          name: description,
          amount: amount,
          date: date,
          currency: extract_currency_from_tink_data(transaction_data),
          raw_payload: transaction_data.to_json
        )

        transaction.save!
        Rails.logger.debug "Saved transaction #{transaction.id}"
      else
        Rails.logger.debug "Transaction #{transaction.id} unchanged, skipping"
      end

    rescue => e
      Rails.logger.error "Error processing transaction #{transaction_data['id']}: #{e.message}"
      raise e
    end

    def extract_amount_from_tink_data(transaction_data)
      amount_info = transaction_data.dig('amount', 'value')
      return 0 unless amount_info

      unscaled_value = amount_info['unscaledValue']
      scale = amount_info['scale'].to_i

      return 0 unless unscaled_value

      # Convert unscaled value and scale to decimal
      # Tink amounts are signed (negative for debits, positive for credits)
      BigDecimal(unscaled_value) / (10 ** scale)
    rescue => e
      Rails.logger.error "Error extracting transaction amount: #{e.message}, amount_info: #{amount_info}"
      0
    end

    def extract_currency_from_tink_data(transaction_data)
      transaction_data.dig('amount', 'currencyCode') || tink_account.currency || 'EUR'
    end

    def transaction_needs_update?(transaction, transaction_data)
      # Check if key fields have changed
      new_amount = extract_amount_from_tink_data(transaction_data)
      new_description = transaction_data['description'] || transaction_data['originalDescription'] || 'Tink Transaction'
      new_date = Date.parse(transaction_data['date'])

      transaction.amount != new_amount ||
        transaction.name != new_description ||
        transaction.date != new_date
    end
end