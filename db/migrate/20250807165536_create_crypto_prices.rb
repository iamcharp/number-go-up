class CreateCryptoPrices < ActiveRecord::Migration[7.2]
  def change
    create_table :crypto_prices, id: :uuid do |t|
      t.references :crypto_asset, null: false, foreign_key: true, type: :uuid
      t.decimal :price
      t.date :date
      t.string :currency

      t.timestamps
    end
  end
end
