module TinkConnectable
  extend ActiveSupport::Concern

  included do
    has_many :tink_items, dependent: :destroy
    has_many :tink_accounts, through: :tink_items
  end

  def can_connect_tink?
    tink_provider.present?
  end

  def tink_provider
    Provider::Registry.tink
  end

  def create_tink_item!(authorization_code:, provider_name:, redirect_uri: nil)
    raise "Tink provider not available" unless can_connect_tink?

    token_response = tink_provider.exchange_authorization_code(
      authorization_code, 
      redirect_uri: redirect_uri
    )
    
    tink_item = tink_items.create!(
      name: provider_name,
      tink_user_id: token_response.user_id,
      access_token: token_response.access_token,
      refresh_token: token_response.refresh_token,
      provider_name: provider_name,
      consent_expires_at: token_response.expires_at,
      institution_id: token_response.institution_id,
      institution_name: token_response.institution_name,
      institution_logo_url: token_response.institution_logo_url,
      raw_payload: token_response.raw_data.to_json
    )
    
    # Start initial sync
    tink_item.sync_later
    tink_item
  end

  def tink_connection_status
    return :unavailable unless can_connect_tink?
    return :disconnected if tink_items.empty?
    
    if tink_items.any?(&:needs_update?)
      :requires_update
    else
      :connected
    end
  end
end