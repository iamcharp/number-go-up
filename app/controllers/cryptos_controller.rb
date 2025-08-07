class CryptosController < ApplicationController
  include AccountableResource

  permitted_accountable_attributes :kraken_api_key, :kraken_private_key, :exchange_name


  def sync_kraken
    @account = Current.family.accounts.find(params[:id])

    if @account.accountable.sync_with_kraken_later
      redirect_to @account, notice: "Kraken sync scheduled successfully"
    else
      redirect_to @account, alert: "Failed to schedule Kraken sync"
    end
  end

  private

    def account_params
      params.require(:account).permit(
        :name, :balance, :accountable_type, :currency, :return_to,
        accountable_attributes: [
          :id,
          *self.class.permitted_accountable_attributes
        ]
      )
    end
end
