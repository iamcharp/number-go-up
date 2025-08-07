class AddKrakenAccountToAccounts < ActiveRecord::Migration[7.2]
  def change
    add_reference :accounts, :kraken_account, null: true, foreign_key: true, type: :uuid, index: false
    add_index :accounts, [:kraken_account_id], where: "kraken_account_id IS NOT NULL", name: "index_accounts_on_kraken_account_id_not_null"
  end
end
