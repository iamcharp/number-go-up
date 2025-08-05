module AccountsHelper
  def summary_card(title:, &block)
    content = capture(&block)
    render "accounts/summary_card", title: title, content: content
  end

  def sync_linked_account_path(account)
    if account.plaid_account_id.present?
      sync_plaid_item_path(account.plaid_account.plaid_item)
    elsif account.tink_account_id.present?
      sync_tink_item_path(account.tink_account.tink_item)
    else
      sync_account_path(account)
    end
  end
end
