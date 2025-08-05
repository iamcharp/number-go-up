class TinkEntry::Processor
  # tink_transaction is the raw hash fetched from Tink API
  def initialize(tink_transaction, tink_account:, category_matcher:)
    @tink_transaction = tink_transaction
    @tink_account = tink_account
    @category_matcher = category_matcher
  end

  def process
    TinkAccount.transaction do
      entry = account.entries.find_or_initialize_by(tink_id: tink_id) do |e|
        e.entryable = Transaction.new
      end

      entry.assign_attributes(
        amount: amount,
        currency: currency,
        date: date
      )

      entry.enrich_attribute(
        :name,
        name,
        source: "tink"
      )

      # TODO: Implement category matching for Tink when needed
      # if detailed_category
      #   matched_category = category_matcher.match(detailed_category)
      #   if matched_category
      #     entry.transaction.enrich_attribute(
      #       :category_id,
      #       matched_category.id,
      #       source: "tink"
      #     )
      #   end
      # end

      entry.save!
      Rails.logger.debug "Created entry #{entry.id} for Tink transaction #{tink_id}"
    end
  end

  private
    attr_reader :tink_transaction, :tink_account, :category_matcher

    def account
      tink_account.account
    end

    def tink_id
      tink_transaction['id']
    end

    def amount
      amount_info = tink_transaction.dig('amount', 'value')
      return 0 unless amount_info

      unscaled_value = amount_info['unscaledValue']
      scale = amount_info['scale'].to_i

      return 0 unless unscaled_value

      # Convert unscaled value and scale to decimal
      # Tink amounts are signed (negative for debits, positive for credits)
      BigDecimal(unscaled_value) / (10 ** scale)
    rescue => e
      Rails.logger.error "Error extracting Tink transaction amount: #{e.message}, amount_info: #{amount_info}"
      0
    end

    def currency
      tink_transaction.dig('amount', 'currencyCode') || tink_account.currency || 'EUR'
    end

    def date
      date_str = tink_transaction.dig('dates', 'booked') || tink_transaction['date']
      Date.parse(date_str) if date_str
    rescue => e
      Rails.logger.error "Error parsing Tink transaction date: #{e.message}, date_data: #{tink_transaction['dates']}"
      Date.current
    end

    def name
      tink_transaction.dig('descriptions', 'display') || 
      tink_transaction.dig('descriptions', 'original') || 
      tink_transaction['description'] || 
      tink_transaction['originalDescription'] || 
      'Tink Transaction'
    end
end