class CreateCryptoAssets < ActiveRecord::Migration[7.2]
  def change
    create_table :crypto_assets, id: :uuid do |t|
      t.string :symbol
      t.string :name
      t.integer :decimals
      t.boolean :can_deposit
      t.boolean :can_withdraw
      t.string :exchange_name

      t.timestamps
    end
  end
end
