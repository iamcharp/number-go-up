class AddTinkTransactionIdToTransactions < ActiveRecord::Migration[7.2]
  def change
    add_column :transactions, :tink_transaction_id, :string
  end
end
