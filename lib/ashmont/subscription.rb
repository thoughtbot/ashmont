require "ashmont/errors"
require "active_support/core_ext"
require "braintree"

module Ashmont
  class Subscription
    attr_reader :token, :errors

    def initialize(token = nil, cached_attributes = {})
      @token = token
      @cached_attributes = cached_attributes
      @errors = {}
    end

    delegate :transactions, :to => :remote_subscription, :allow_nil => true

    def status
      @cached_attributes[:status] || remote_status
    end

    def save(attributes)
      attributes_for_merchant = add_merchant_to_attributes(attributes)
      if token
        update(attributes_for_merchant)
      else
        create(attributes_for_merchant)
      end
    end

    def retry_charge
      transaction = Braintree::Subscription.retry_charge(token).transaction
      result = Braintree::Transaction.submit_for_settlement(transaction.id)
      reload
      if result.success?
        true
      else
        @errors = Ashmont::Errors.new(transaction, result.errors)
        false
      end
    end

    def most_recent_transaction
      transactions.sort_by(&:created_at).last
    end

    def next_billing_date
      merchant_account_time_zone.parse(remote_subscription.next_billing_date)
    end

    def reload
      @remote_subscription = nil
      @cached_attributes = {}
      self
    end

    def past_due?
      status == Braintree::Subscription::Status::PastDue
    end

    private

    def remote_status
      remote_subscription.status if remote_subscription
    end

    def add_merchant_to_attributes(attributes)
      if Ashmont.merchant_account_id
        attributes.merge(:merchant_account_id => Ashmont.merchant_account_id)
      else
        attributes
      end
    end

    def create(attributes)
      result = Braintree::Subscription.create(attributes)
      if result.success?
        @token = result.subscription.id
        @remote_subscription = result.subscription
        true
      else
        false
      end
    end

    def update(attributes)
      @remote_subscription = nil
      Braintree::Subscription.update(token, attributes)
    end

    def remote_subscription
      @remote_subscription ||= find_remote_subscription
    end

    def find_remote_subscription
      if token
        Braintree::Subscription.find(token)
      end
    end

    def merchant_account_time_zone
      ActiveSupport::TimeZone[Ashmont.merchant_account_time_zone]
    end
  end
end
