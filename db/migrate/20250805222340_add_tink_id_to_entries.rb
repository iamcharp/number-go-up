class AddTinkIdToEntries < ActiveRecord::Migration[7.2]
  def change
    add_column :entries, :tink_id, :string
  end
end
