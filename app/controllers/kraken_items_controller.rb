class KrakenItemsController < ApplicationController
  before_action :set_kraken_item, only: [ :edit, :update, :destroy, :sync ]

  def new
    @accountable_type = params[:accountable_type] || "Crypto"
    @kraken_item = KrakenItem.new
  end

  def create
    begin
      @kraken_item = Current.family.connect_kraken_exchange(
        name: kraken_item_params[:name],
        api_key: kraken_item_params[:api_key],
        private_key: kraken_item_params[:private_key]
      )

      if @kraken_item.persisted?
        # Test connection
        if @kraken_item.test_connection
          # Process initial accounts
          @kraken_item.process_accounts
          redirect_to accounts_path, notice: "Kraken exchange connected successfully! Found #{@kraken_item.kraken_accounts.count} assets."
        else
          @kraken_item.destroy
          @error_message = "Failed to connect to Kraken. Please check your API credentials."
          render :new, status: :unprocessable_entity
        end
      else
        @error_message = "Failed to save Kraken connection: #{@kraken_item.errors.full_messages.join(', ')}"
        render :new, status: :unprocessable_entity
      end
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error "Kraken validation error: #{e.message}"
      Rails.logger.error "Full error: #{e.record.errors.full_messages}"
      @kraken_item ||= KrakenItem.new(kraken_item_params)
      @error_message = "Validation failed: #{e.record.errors.full_messages.join(', ')}"
      render :new, status: :unprocessable_entity
    rescue => e
      Rails.logger.error "Kraken connection error: #{e.message}"
      Rails.logger.error "Error backtrace: #{e.backtrace.first(5).join('\n')}"
      @kraken_item ||= KrakenItem.new(kraken_item_params)
      @error_message = "Connection error: #{e.message}"
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @kraken_item.update(kraken_item_params)
      redirect_to accounts_path, notice: "Kraken connection updated successfully"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @kraken_item.destroy_later
    redirect_to accounts_path, notice: "Kraken connection scheduled for deletion"
  end

  def sync
    @kraken_item.sync_later
    redirect_to accounts_path, notice: "Kraken sync scheduled"
  end

  private

    def set_kraken_item
      @kraken_item = Current.family.kraken_items.find(params[:id])
    end

    def kraken_item_params
      params.require(:kraken_item).permit(:name, :api_key, :private_key)
    end
end