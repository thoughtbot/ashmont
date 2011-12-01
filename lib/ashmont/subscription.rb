require "ashmont/errors"
require "active_support/core_ext"
require "braintree"

module Ashmont
  class Subscription
    attr_reader :token, :errors

    def initialize(attributes = {})
      @attributes = attributes.except(:token)
      @token = attributes[:token]
      @errors = {}
    end

    delegate :transactions, :status, :to => :remote_subscription

    def save
      if token
        update
      else
        create
      end
    end

    def retry_charge
      transaction = Braintree::Subscription.retry_charge(token).transaction
      result = Braintree::Transaction.submit_for_settlement(transaction.id)
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
      self
    end

    private

    def create
      result = Braintree::Subscription.create(@attributes)
      if result.success?
        @token = result.subscription.id
        @remote_subscription = result.subscription
        true
      else
        false
      end
    end

    def update
      @remote_subscription = nil
      Braintree::Subscription.update(token, @attributes)
    end

    def remote_subscription
      @remote_subscription ||= Braintree::Subscription.find(token)
    end

    def merchant_account_time_zone
      ActiveSupport::TimeZone[Ashmont.merchant_account_time_zone]
    end
  end
end
