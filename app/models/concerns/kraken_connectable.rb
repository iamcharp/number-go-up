module KrakenConnectable
  extend ActiveSupport::Concern

  included do
    has_many :kraken_items, dependent: :destroy
    has_many :kraken_accounts, through: :kraken_items
  end

  def can_connect_kraken?
    true # Kraken doesn't require special provider config, just API keys
  end

  def kraken_provider
    # This could later check for global Kraken settings if needed
    Provider::Registry.kraken
  end

  def connect_kraken_exchange(name:, api_key:, private_key:)
    kraken_item = kraken_items.create!(
      name: name,
      api_key: api_key,
      private_key: private_key,
      provider_name: "Kraken",
      status: "good"
    )

    # Start initial sync
    kraken_item.sync_later
    kraken_item
  end

  def kraken_connection_status
    return :disconnected if kraken_items.empty?

    if kraken_items.any?(&:needs_update?)
      :requires_update
    else
      :connected
    end
  end
end