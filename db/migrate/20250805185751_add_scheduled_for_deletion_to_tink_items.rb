class AddScheduledForDeletionToTinkItems < ActiveRecord::Migration[7.2]
  def change
    add_column :tink_items, :scheduled_for_deletion, :boolean, default: false, null: false
  end
end
