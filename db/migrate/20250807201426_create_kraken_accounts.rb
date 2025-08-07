class CreateKrakenAccounts < ActiveRecord::Migration[7.2]
  def change
    create_table :kraken_accounts, id: :uuid do |t|
      t.references :kraken_item, null: false, foreign_key: true, type: :uuid
      t.string :kraken_id, null: false # asset symbol from Kraken (BTC, ETH, etc.)
      t.string :name, null: false # display name
      t.string :asset_symbol, null: false # crypto symbol
      t.string :asset_name # full name (Bitcoin, Ethereum, etc.)
      t.string :currency, null: false, default: "USD"
      t.decimal :balance, precision: 30, scale: 10, default: 0.0 # quantity of asset
      t.decimal :available_balance, precision: 30, scale: 10 # available quantity
      t.decimal :locked_balance, precision: 30, scale: 10, default: 0.0 # locked in orders
      t.decimal :usd_value, precision: 19, scale: 4, default: 0.0 # value in USD
      t.decimal :last_price, precision: 19, scale: 4 # last known price
      t.text :raw_payload

      t.timestamps
    end

    add_index :kraken_accounts, :kraken_id, unique: true
    add_index :kraken_accounts, :asset_symbol
    add_index :kraken_accounts, [:kraken_item_id, :asset_symbol], unique: true
  end
end
