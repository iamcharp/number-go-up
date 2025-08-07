class CreateTinkItems < ActiveRecord::Migration[7.2]
  def change
    create_table :tink_items, id: :uuid do |t|
      t.references :family, null: false, foreign_key: true, type: :uuid
      t.string :name, null: false
      t.string :access_token, null: false
      t.string :refresh_token
      t.string :tink_user_id, null: false
      t.string :provider_name, null: false
      t.datetime :consent_expires_at
      t.string :status, default: "good"
      t.string :institution_id
      t.string :institution_name
      t.string :institution_logo_url
      t.text :raw_payload

      t.timestamps
    end

    add_index :tink_items, :tink_user_id
    add_index :tink_items, :provider_name
  end
end
