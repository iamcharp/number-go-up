class TinkAccount < ApplicationRecord
  include TinkAccount::TypeMappable

  belongs_to :tink_item
  has_one :account, dependent: :destroy
  has_one :family, through: :tink_item

  validates :tink_id, :name, :account_type, :currency, presence: true
  validates :tink_id, uniqueness: true

  scope :active, -> { joins(:account).where(accounts: { active: true }) }

  def balance_money
    Money.new(balance, currency) if balance.present?
  end

  def available_balance_money
    Money.new(available_balance, currency) if available_balance.present?
  end

  def create_account!
    return account if account.present?

    mapped_type = map_account_type(account_type)
    
    account_attrs = {
      family: family,
      name: name,
      balance: balance || 0,
      currency: currency,
      subtype: mapped_type[:subtype],
      accountable_type: mapped_type[:accountable_type],
      accountable_attributes: mapped_type[:accountable_attributes],
      tink_account: self
    }

    self.account = Account.create!(account_attrs)
  end

  def sync_balance!
    return unless account.present?

    account.update!(
      balance: balance || 0,
      updated_at: Time.current
    )
  end

  def upsert_tink_snapshot!(raw_data)
    update!(
      raw_payload: raw_data.to_json,
      balance: extract_balance(raw_data),
      available_balance: extract_available_balance(raw_data),
      name: raw_data["name"] || name,
      account_number: raw_data["accountNumber"],
      iban: raw_data["iban"],
      sort_code: raw_data["sortCode"]
    )
  end

  private

    def extract_balance(raw_data)
      balance_data = raw_data["balances"]&.find { |b| b["type"] == "BOOKED" }
      balance_data&.dig("amount", "value")&.to_d
    end

    def extract_available_balance(raw_data)
      balance_data = raw_data["balances"]&.find { |b| b["type"] == "AVAILABLE" }
      balance_data&.dig("amount", "value")&.to_d
    end
end