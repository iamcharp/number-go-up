class TinkItem < ApplicationRecord
  include Syncable

  enum :status, { good: "good", requires_update: "requires_update" }, default: :good

  if Rails.application.credentials.active_record_encryption.present?
    encrypts :access_token, deterministic: true
    encrypts :refresh_token, deterministic: true
  end

  validates :name, :access_token, :tink_user_id, :provider_name, presence: true

  before_destroy :remove_tink_item

  belongs_to :family
  has_one_attached :logo

  has_many :tink_accounts, dependent: :destroy
  has_many :accounts, through: :tink_accounts

  has_many :syncs, as: :syncable, dependent: :destroy

  scope :active, -> { where(scheduled_for_deletion: false) }
  scope :ordered, -> { order(created_at: :desc) }

  def provider
    @provider ||= Provider::Registry.tink
  end

  def needs_update?
    status == "requires_update"
  end

  def consent_expired?
    consent_expires_at.present? && consent_expires_at < Time.current
  end

  def process_accounts
    tink_accounts.each do |tink_account|
      TinkAccount::Processor.new(tink_account).process
    end
  end

  def schedule_account_syncs(parent_sync: nil, window_start_date: nil, window_end_date: nil)
    accounts.each do |account|
      account.sync_later(
        parent_sync: parent_sync,
        window_start_date: window_start_date,
        window_end_date: window_end_date
      )
    end
  end

  def destroy_later
    update!(scheduled_for_deletion: true)
    DestroyJob.perform_later(self)
  end

  def refresh_access_token!
    return unless refresh_token.present?

    response = provider.refresh_token(refresh_token)
    update!(
      access_token: response.access_token,
      refresh_token: response.refresh_token || refresh_token,
      consent_expires_at: response.expires_at
    )
  rescue => e
    Rails.logger.error "Failed to refresh Tink token: #{e.message}"
    update!(status: :requires_update)
    raise
  end

  private

    def remove_tink_item
      return unless provider.present?

      begin
        provider.remove_item(access_token)
      rescue => e
        Rails.logger.error "Failed to remove Tink item: #{e.message}"
      end
    end
end
