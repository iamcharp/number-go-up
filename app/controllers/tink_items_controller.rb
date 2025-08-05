class TinkItemsController < ApplicationController
  before_action :set_tink_item, only: [:edit, :update, :destroy, :sync]

  def new
    @accountable_type = params[:accountable_type]
    
    unless Current.family.can_connect_tink?
      redirect_to accounts_path, alert: "Tink integration is not available"
      return
    end

    # Generate OAuth URL and redirect to Tink
    tink_provider = Current.family.tink_provider
    state = SecureRandom.hex(16)
    
    authorization_url = tink_provider.get_authorization_url(state: state)
    
    # Debug: log the URL we're generating
    Rails.logger.info "Tink Authorization URL: #{authorization_url}"
    
    # Store state in session for verification
    session[:tink_oauth_state] = state
    
    redirect_to authorization_url, allow_other_host: true
  end

  def create
    # TODO: Implement Tink connection flow
    redirect_to accounts_path, notice: "Tink integration coming soon!"
  end

  def edit
    # TODO: Implement Tink item editing
  end

  def update
    # TODO: Implement Tink item updates
  end

  def destroy
    @tink_item.destroy_later
    redirect_to accounts_path, notice: "Tink connection scheduled for deletion"
  end

  def sync
    @tink_item.sync_later
    redirect_to accounts_path, notice: "Tink sync started!"
  end

  def callback
    authorization_code = params[:code]
    state = params[:state]
    error = params[:error]

    Rails.logger.info "Tink callback - Current.user: #{Current.user&.id}, Current.family: #{Current.family&.id}"

    if error.present?
      redirect_to root_path, alert: "Tink connection failed: #{error}"
      return
    end

    if authorization_code.blank?
      redirect_to root_path, alert: "No authorization code received from Tink"
      return
    end

    # Check if user is authenticated
    unless Current.user&.persisted?
      Rails.logger.warn "Tink callback: User not authenticated, redirecting to sign in"
      redirect_to new_session_path, alert: "Please sign in to continue connecting your Tink account"
      return
    end

    begin
      # Create Tink item with authorization code
      tink_item = Current.family.create_tink_item!(
        authorization_code: authorization_code,
        provider_name: "Tink Sandbox Bank", # Default name, will be updated with real bank name
        redirect_uri: Rails.application.config.tink[:redirect_uri]
      )

      # Fetch and create real Tink accounts
      create_real_tink_accounts(tink_item)

      # Start sync job to process transactions
      tink_item.sync_later

      redirect_to root_path, notice: "Successfully connected to Tink! Syncing accounts and transactions..."
    rescue => e
      Rails.logger.error "Tink callback error: #{e.message}"
      redirect_to root_path, alert: "Failed to connect Tink account: #{e.message}"
    end
  end

  private

    def set_tink_item
      @tink_item = Current.family.tink_items.find(params[:id])
    end

    def tink_item_params
      params.require(:tink_item).permit(:name, :provider_name)
    end

    def create_test_tink_accounts(tink_item)
      # Create test checking account
      checking_account = tink_item.tink_accounts.create!(
        tink_id: "test_checking_#{SecureRandom.hex(8)}",
        name: "Tink Test Checking",
        account_type: "CHECKING",
        currency: "EUR",
        balance: 2500.75,
        available_balance: 2450.75,
        account_number: "FR76 3000 3033 0000 0203 9000 541",
        iban: "FR7630003033000002039000541"
      )

      # Create test savings account
      savings_account = tink_item.tink_accounts.create!(
        tink_id: "test_savings_#{SecureRandom.hex(8)}",
        name: "Tink Test Savings",
        account_type: "SAVINGS", 
        currency: "EUR",
        balance: 8750.25,
        available_balance: 8750.25,
        account_number: "FR76 3000 3033 0000 0203 9000 542",
        iban: "FR7630003033000002039000542"
      )

      # Create Maybe accounts from TinkAccounts
      [checking_account, savings_account].each do |tink_account|
        tink_account.create_account!
      end

      Rails.logger.info "Created #{tink_item.tink_accounts.count} test Tink accounts"
    end

    def create_real_tink_accounts(tink_item)
      # Fetch real accounts from Tink API
      accounts_data = tink_item.provider.get_accounts(tink_item.access_token)
      
      Rails.logger.info "Fetched #{accounts_data.count} accounts from Tink API"
      Rails.logger.info "Raw accounts data: #{accounts_data.inspect}"
      
      accounts_data.each_with_index do |account_data, index|
        begin
          Rails.logger.info "Processing account #{index + 1}: #{account_data.inspect}"
          
          # Map Tink account type to our system
          account_type = map_tink_account_type(account_data['type'])
          Rails.logger.info "Mapped account type: #{account_type}"
          
          # Extract balance information
          balance = extract_balance_from_tink_data(account_data)
          available_balance = extract_available_balance_from_tink_data(account_data)
          Rails.logger.info "Extracted balances - balance: #{balance}, available: #{available_balance}"
          
          # Extract currency from Tink balance data
          currency = account_data.dig('balances', 'booked', 'amount', 'currencyCode') ||
                     account_data.dig('balances', 'available', 'amount', 'currencyCode') ||
                     'EUR'
          
          # Create TinkAccount
          tink_account = tink_item.tink_accounts.create!(
            tink_id: account_data['id'],
            name: account_data['name'],
            account_type: account_type,
            currency: currency,
            balance: balance,
            available_balance: available_balance,
            account_number: account_data.dig('identifiers', 'financialInstitution', 'accountNumber'),
            iban: account_data.dig('identifiers', 'iban', 'iban'),
            raw_payload: account_data.to_json
          )
          
          Rails.logger.info "Created TinkAccount: #{tink_account.id}"
          
          # Create corresponding Maybe Account
          tink_account.create_account!
          Rails.logger.info "Created Account: #{tink_account.account.id}"
          
        rescue => e
          Rails.logger.error "Error processing account #{index + 1}: #{e.message}"
          Rails.logger.error "Account data: #{account_data.inspect}"
          raise e
        end
      end
      
      Rails.logger.info "Created #{tink_item.tink_accounts.count} real Tink accounts"
    end

    def map_tink_account_type(tink_type)
      case tink_type&.upcase
      when 'CHECKING', 'CURRENT_ACCOUNT'
        'CHECKING'
      when 'SAVINGS', 'SAVINGS_ACCOUNT'
        'SAVINGS'
      when 'CREDIT_CARD'
        'CREDIT_CARD'
      when 'LOAN', 'MORTGAGE'
        'LOAN'
      when 'INVESTMENT'
        'INVESTMENT'
      else
        'CHECKING' # Default fallback
      end
    end

    def extract_balance_from_tink_data(account_data)
      # Tink API format: balances.booked.amount.value.{unscaledValue, scale}
      balance_info = account_data.dig('balances', 'booked', 'amount', 'value')
      return 0 unless balance_info
      
      unscaled_value = balance_info['unscaledValue']
      scale = balance_info['scale'].to_i
      
      return 0 unless unscaled_value
      
      # Convert unscaled value and scale to decimal
      # Example: unscaledValue="5500", scale="2" = 55.00
      BigDecimal(unscaled_value) / (10 ** scale)
    rescue => e
      Rails.logger.error "Error extracting balance: #{e.message}, balance_info: #{balance_info}"
      0
    end

    def extract_available_balance_from_tink_data(account_data)
      # Tink API format: balances.available.amount.value.{unscaledValue, scale}
      balance_info = account_data.dig('balances', 'available', 'amount', 'value')
      return nil unless balance_info
      
      unscaled_value = balance_info['unscaledValue']
      scale = balance_info['scale'].to_i
      
      return nil unless unscaled_value
      
      # Convert unscaled value and scale to decimal
      BigDecimal(unscaled_value) / (10 ** scale)
    rescue => e
      Rails.logger.error "Error extracting available balance: #{e.message}, balance_info: #{balance_info}"
      nil
    end
end