class Provider::Tink
  def initialize(config)
    @config = config
    @client_id = config[:client_id]
    @client_secret = config[:client_secret]
    @environment = config[:environment]
    @base_url = config[:base_url]
    @redirect_uri = config[:redirect_uri]
  end

  def available?
    @client_id.present? && @client_secret.present?
  end

  # OAuth flow methods
  def get_authorization_url(state: nil)
    # Tink OAuth authorization URL (works for both sandbox and production)
    params = {
      client_id: @client_id,
      redirect_uri: @redirect_uri,
      market: "FR", # French market for European banks
      locale: "en_US",
      scope: "accounts:read,transactions:read,user:read,credentials:read",
      state: state
    }.compact
    
    "https://oauth.tink.com/0.4/authorize?" + params.to_query
  end

  def exchange_authorization_code(code, redirect_uri: nil)
    require 'net/http'
    require 'uri'
    require 'json'

    uri = URI('https://api.tink.se/api/v1/oauth/token')
    
    params = {
      'code' => code,
      'client_id' => @client_id,
      'client_secret' => @client_secret,
      'grant_type' => 'authorization_code'
    }
    
    response = Net::HTTP.post_form(uri, params)
    
    if response.code == '200'
      token_data = JSON.parse(response.body)
      
      # Get user info to extract user_id
      user_info = get_user_info(token_data['access_token'])
      
      OpenStruct.new(
        access_token: token_data['access_token'],
        refresh_token: token_data['refresh_token'],
        user_id: user_info['user_id'] || "tink_user_#{SecureRandom.hex(8)}",
        expires_at: Time.current + token_data['expires_in'].seconds,
        institution_id: "tink_bank",
        institution_name: "Tink Connected Bank",
        institution_logo_url: nil,
        raw_data: token_data
      )
    else
      Rails.logger.error "Tink token exchange failed: #{response.code} #{response.body}"
      raise "Tink API error: #{response.code} - #{JSON.parse(response.body)['message'] rescue response.body}"
    end
  rescue => e
    Rails.logger.error "Tink token exchange error: #{e.message}"
    raise "Failed to exchange Tink authorization code: #{e.message}"
  end

  def get_user_info(access_token)
    require 'net/http'
    require 'uri'
    require 'json'

    uri = URI('https://api.tink.se/api/v1/user')
    
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    
    request = Net::HTTP::Get.new(uri)
    request['Authorization'] = "Bearer #{access_token}"
    
    response = http.request(request)
    
    if response.code == '200'
      JSON.parse(response.body)
    else
      Rails.logger.error "Tink user info failed: #{response.code} #{response.body}"
      {}
    end
  rescue => e
    Rails.logger.error "Tink user info error: #{e.message}"
    {}
  end

  def get_accounts(access_token)
    require 'net/http'
    require 'uri'
    require 'json'

    uri = URI('https://api.tink.se/data/v2/accounts')
    
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    
    request = Net::HTTP::Get.new(uri)
    request['Authorization'] = "Bearer #{access_token}"
    
    response = http.request(request)
    
    if response.code == '200'
      data = JSON.parse(response.body)
      data['accounts'] || []
    else
      Rails.logger.error "Tink accounts failed: #{response.code} #{response.body}"
      []
    end
  rescue => e
    Rails.logger.error "Tink accounts error: #{e.message}"
    []
  end

  def get_transactions(access_token, account_id:, from_date: nil, to_date: nil)
    require 'net/http'
    require 'uri'
    require 'json'

    # Default date range if not provided
    from_date ||= 90.days.ago.to_date
    to_date ||= Date.current

    uri = URI('https://api.tink.se/data/v2/transactions')
    
    # Add query parameters
    params = {
      'accountIds' => account_id,
      'startDate' => from_date.strftime('%Y-%m-%d'),
      'endDate' => to_date.strftime('%Y-%m-%d')
    }
    
    uri.query = URI.encode_www_form(params)
    
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    
    request = Net::HTTP::Get.new(uri)
    request['Authorization'] = "Bearer #{access_token}"
    
    response = http.request(request)
    
    if response.code == '200'
      data = JSON.parse(response.body)
      Rails.logger.info "Fetched #{data['transactions']&.count || 0} transactions for account #{account_id}"
      data['transactions'] || []
    else
      Rails.logger.error "Tink transactions failed: #{response.code} #{response.body}"
      []
    end
  rescue => e
    Rails.logger.error "Tink transactions error: #{e.message}"
    []
  end

  def refresh_token(refresh_token)
    # TODO: Implement real Tink API call
    OpenStruct.new(
      access_token: "refreshed_access_token_#{SecureRandom.hex(16)}",
      refresh_token: refresh_token,
      expires_at: 90.days.from_now
    )
  end

  def remove_item(access_token)
    # TODO: Implement real Tink API call
    true
  end

  private

    attr_reader :config, :client_id, :client_secret, :environment, :base_url, :redirect_uri
end