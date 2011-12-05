module Ashmont
  class Customer
    attr_reader :token, :errors

    def initialize(token = nil)
      @token = token
      @errors = {}
    end

    def credit_card
      if persisted?
        remote_customer.credit_cards[0]
      end
    end

    def has_billing_info?
      credit_card.present?
    end

    def payment_method_token
      credit_card.token if credit_card
    end

    def billing_email
      remote_customer.email if persisted?
    end

    def save(attributes)
      handle_result create_or_update(attributes)
    end

    def delete
      Braintree::Customer.delete(@token)
    end

    def last_4
      credit_card.last_4 if credit_card
    end

    def cardholder_name
      credit_card.cardholder_name if credit_card
    end

    def expiration_month
      credit_card.expiration_month if credit_card
    end

    def expiration_year
      credit_card.expiration_year if credit_card
    end

    def street_address
      credit_card.billing_address.street_address if credit_card
    end

    def extended_address
      credit_card.billing_address.extended_address if credit_card
    end

    def locality
      credit_card.billing_address.locality if credit_card
    end

    def region
      credit_card.billing_address.region if credit_card
    end

    def postal_code
      credit_card.billing_address.postal_code if credit_card
    end

    def country_name
      credit_card.billing_address.country_name if credit_card
    end

    private

    def create_or_update(attributes)
      if persisted?
        update(attributes)
      else
        create(attributes)
      end
    end

    def create(attributes)
      Braintree::Customer.create(attributes)
    end

    def update(attributes)
      Braintree::Customer.update(@token, attributes)
    end

    def handle_result(result)
      if result.success?
        @token = result.customer.id
        @remote_customer = result.customer
        true
      else
        @errors = Ashmont::Errors.new(result.credit_card_verification, result.errors)
        false
      end
    end

    def persisted?
      @token.present?
    end

    def remote_customer
      @remote_customer ||= Braintree::Customer.find(@token)
    end
  end
end
