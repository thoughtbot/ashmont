require 'spec_helper'

describe Ashmont::Subscription do
  %w(transactions status).each do |delegated_method|
    it "delegates ##{delegated_method} to the remote subscription" do
      token = 'xyz'
      remote_subscription = stub("remote-subscription", delegated_method => "expected")
      Braintree::Subscription.stubs(:find => remote_subscription)
      subscription = Ashmont::Subscription.new(token)
      result = subscription.send(delegated_method)
      Braintree::Subscription.should have_received(:find).with(token)
      result.should == "expected"
    end
  end

  it "converts the next billing date into the configured timezone" do
    unconverted_date = "2011-01-20"
    remote_subscription = stub("remote-subscription", :next_billing_date => unconverted_date)
    Braintree::Subscription.stubs(:find => remote_subscription)
    subscription = Ashmont::Subscription.new
    result = subscription.next_billing_date
    result.utc_offset.should == ActiveSupport::TimeZone[Ashmont.merchant_account_time_zone].utc_offset
    result.strftime("%Y-%m-%d").should == unconverted_date
  end

  it "returns the token" do
    subscription = Ashmont::Subscription.new('abc')
    subscription.token.should == 'abc'
  end

  it "retries a subscription" do
    subscription_token = 'xyz'
    transaction_token = 'abc'
    transaction = stub("transaction", :id => transaction_token)
    retry_result = stub("retry-result", :transaction => transaction)
    settlement_result = stub("settlement-result", :success? => true)
    Braintree::Subscription.stubs(:retry_charge => retry_result)
    Braintree::Transaction.stubs(:submit_for_settlement => settlement_result)

    subscription = Ashmont::Subscription.new(subscription_token)
    subscription.retry_charge.should be_true
    subscription.errors.should be_empty

    Braintree::Subscription.should have_received(:retry_charge).with(subscription_token)
    Braintree::Transaction.should have_received(:submit_for_settlement).with(transaction_token)
  end

  it "has errors after a failed subscription retry" do
    subscription_token = 'xyz'
    transaction_token = 'abc'
    transaction = stub("transaction", :id => transaction_token)
    error_messages = "failure"
    errors = "errors"
    retry_result = stub("retry-result", :transaction => transaction)
    settlement_result = stub("settlement-result", :success? => false, :errors => error_messages)
    Braintree::Subscription.stubs(:retry_charge => retry_result)
    Braintree::Transaction.stubs(:submit_for_settlement => settlement_result)
    Ashmont::Errors.stubs(:new => errors)

    subscription = Ashmont::Subscription.new(subscription_token)
    subscription.retry_charge.should be_false
    subscription.errors.should == errors

    Braintree::Subscription.should have_received(:retry_charge).with(subscription_token)
    Braintree::Transaction.should have_received(:submit_for_settlement).with(transaction_token)
    Ashmont::Errors.should have_received(:new).with(transaction, error_messages)
  end

  it "updates a subscription" do
    token = 'xyz'
    Braintree::Subscription.stubs(:update => 'expected')

    subscription = Ashmont::Subscription.new(token)
    result = subscription.save(:name => "Billy")

    Braintree::Subscription.should have_received(:update).with(token, :name => "Billy")
    result.should == "expected"
  end

  it "creates a successful subscription" do
    attributes = { "test" => "hello" }
    token = "xyz"
    remote_subscription = stub('remote-subscription', :id => token, :status => "fine")
    result = stub("result", :subscription => remote_subscription, :success? => true)
    Braintree::Subscription.stubs(:create => result)

    subscription = Ashmont::Subscription.new
    subscription.save(attributes).should be_true

    Braintree::Subscription.should have_received(:create).with(attributes)
    subscription.token.should == token
    subscription.status.should == "fine"
  end

  it "returns the most recent transaction" do
    Timecop.freeze(Time.now) do
      dates = [2.days.ago, 3.days.ago, 1.day.ago]
      transactions = dates.map { |date| stub("transaction", :created_at => date) }
      remote_subscription = stub("remote-subscription", :transactions => transactions)
      Braintree::Subscription.stubs(:find => remote_subscription)

      subscription = Ashmont::Subscription.new

      subscription.most_recent_transaction.created_at.should == 1.day.ago
    end
  end

  it "reloads remote data" do
      old_remote_subscription = stub("old-remote-subscription", :status => "old")
      new_remote_subscription = stub("new-remote-subscription", :status => "new")
      Braintree::Subscription.stubs(:find).returns(old_remote_subscription).then.returns(new_remote_subscription)
      subscription = Ashmont::Subscription.new(:token => 'xyz')
      subscription.status.should == "old"
      subscription.reload.status.should == "new"
  end
end
