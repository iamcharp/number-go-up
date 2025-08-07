module TinkAccount::TypeMappable
  extend ActiveSupport::Concern

  private

    def map_account_type(tink_type)
      case tink_type.upcase
      when "CHECKING", "CURRENT"
        {
          accountable_type: "Depository",
          accountable_attributes: {},
          subtype: "checking"
        }
      when "SAVINGS"
        {
          accountable_type: "Depository",
          accountable_attributes: {},
          subtype: "savings"
        }
      when "CREDIT_CARD", "CREDIT"
        {
          accountable_type: "CreditCard",
          accountable_attributes: {},
          subtype: nil
        }
      when "LOAN", "MORTGAGE"
        {
          accountable_type: "Loan",
          accountable_attributes: {},
          subtype: "personal"
        }
      when "INVESTMENT", "PENSION"
        {
          accountable_type: "Investment",
          accountable_attributes: {},
          subtype: nil
        }
      else
        # Default to checking for unknown types
        {
          accountable_type: "Depository",
          accountable_attributes: {},
          subtype: "checking"
        }
      end
    end
end
