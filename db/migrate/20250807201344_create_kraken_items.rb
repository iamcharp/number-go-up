class CreateKrakenItems < ActiveRecord::Migration[7.2]
  def change
    create_table :kraken_items, id: :uuid do |t|
      t.references :family, null: false, foreign_key: true, type: :uuid
      t.string :name, null: false
      t.text :api_key # encrypted
      t.text :private_key # encrypted
      t.string :provider_name, default: "Kraken"
      t.string :status, default: "good"
      t.text :raw_payload
      t.boolean :scheduled_for_deletion, default: false

      t.timestamps
    end

    add_index :kraken_items, :status
    add_index :kraken_items, [:family_id, :provider_name]
  end
end
