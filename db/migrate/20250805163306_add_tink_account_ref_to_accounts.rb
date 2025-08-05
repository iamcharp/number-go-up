class AddTinkAccountRefToAccounts < ActiveRecord::Migration[7.2]
  def change
    add_reference :accounts, :tink_account, null: true, foreign_key: true, type: :uuid
  end
end
