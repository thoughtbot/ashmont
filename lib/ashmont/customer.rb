module Ashmont
  class Customer
    CREDIT_CARD_ATTRIBUTES = [:cardholder_name, :number, :cvv, :expiration_month, :expiration_year].freeze
    ADDRESS_ATTRIBUTES = [:street_address, :extended_address, :locality, :region, :postal_code, :country_name].freeze
    BILLING_ATTRIBUTES = (CREDIT_CARD_ATTRIBUTES + ADDRESS_ATTRIBUTES).freeze

    attr_reader :token, :errors

    def initialize(token = nil)
      @token = token
      @errors = {}
    end

    def credit_card
      credit_cards[0]
    end

    def credit_cards
      if persisted?
        remote_customer.credit_cards
      else
        []
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

    def confirm(query_string)
      handle_result Braintree::TransparentRedirect.confirm(query_string)
    end

    private

    def create_or_update(attributes)
      remote_attributes = build_attribute_hash(attributes.symbolize_keys)
      if persisted?
        update(remote_attributes)
      else
        create(remote_attributes)
      end
    end

    def build_attribute_hash(attributes)
      result = { :email => attributes[:email] }
      if BILLING_ATTRIBUTES.any? { |attribute| attributes[attribute].present? }
        result[:credit_card] = CREDIT_CARD_ATTRIBUTES.inject({}) do |credit_card_attributes, attribute|
          credit_card_attributes.update(attribute => attributes[attribute])
        end
        result[:credit_card][:billing_address] = ADDRESS_ATTRIBUTES.inject({}) do |address_attributes, attribute|
          address_attributes.update(attribute => attributes[attribute])
        end
        if payment_method_token
          result[:credit_card][:options] = { :update_existing_token => payment_method_token }
        end
      else
        result[:credit_card] = {}
      end
      result
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
