require 'delegate'
require 'forwardable'

module Ashmont
  class SubscribedCustomer < DelegateClass(Customer)
    CUSTOMER_ATTRIBUTES = [:cardholder_name, :email, :number,
                           :expiration_month, :expiration_year, :cvv,
                           :street_address, :extended_address, :locality,
                           :region, :postal_code, :country_name]

    extend Forwardable

    def initialize(customer, subscription)
      super(customer)
      @customer = customer
      @subscription = subscription
    end

    def_delegators :@subscription, :reload, :status, :next_billing_date,
      :transactions, :most_recent_transaction, :retry_charge, :past_due?

    def subscription_token
      @subscription.token
    end

    def save(attributes)
      apply_customer_changes(attributes) && ensure_subscription_active && apply_subscription_changes(attributes)
    end

    def errors
      super.to_hash.merge(@subscription.errors.to_hash)
    end

    private

    def apply_customer_changes(attributes)
      if new_customer? || changing_customer?(attributes)
        @customer.save(attributes)
      else
        true
      end
    end

    def new_customer?
      token.nil?
    end

    def changing_customer?(attributes)
      CUSTOMER_ATTRIBUTES.any? { |attribute| attributes[attribute].present? }
    end

    def ensure_subscription_active
      if past_due?
        retry_charge
      else
        true
      end
    end

    def apply_subscription_changes(attributes)
      if changing_subscription?(attributes)
        save_subscription(attributes)
      else
        true
      end
    end

    def changing_subscription?(attributes)
      attributes[:plan_id].present?
    end

    def save_subscription(attributes)
      @subscription.save(
        :plan_id => attributes[:plan_id],
        :price => attributes[:price].to_s,
        :payment_method_token => payment_method_token
      )
    end
  end
end
