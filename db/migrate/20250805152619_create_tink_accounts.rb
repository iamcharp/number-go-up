class CreateTinkAccounts < ActiveRecord::Migration[7.2]
  def change
    create_table :tink_accounts, id: :uuid do |t|
      t.references :tink_item, null: false, foreign_key: true, type: :uuid
      t.string :tink_id, null: false
      t.string :name, null: false
      t.string :account_type, null: false
      t.decimal :balance, precision: 19, scale: 4
      t.decimal :available_balance, precision: 19, scale: 4
      t.string :currency, null: false, default: "EUR"
      t.string :account_number
      t.string :sort_code
      t.string :iban
      t.text :raw_payload

      t.timestamps
    end
    
    add_index :tink_accounts, :tink_id, unique: true
    add_index :tink_accounts, :account_type
  end
end
