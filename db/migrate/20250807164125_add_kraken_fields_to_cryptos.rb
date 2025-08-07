class AddKrakenFieldsToCryptos < ActiveRecord::Migration[7.2]
  def change
    add_column :cryptos, :kraken_api_key, :string
    add_column :cryptos, :kraken_private_key, :string
    add_column :cryptos, :exchange_name, :string
  end
end
