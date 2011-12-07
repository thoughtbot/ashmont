require 'spec_helper'

describe Ashmont::Subscription do
  %w(transactions).each do |delegated_method|
    it "delegates ##{delegated_method} to the remote subscription" do
      remote_subscription = stub_remote_subscription(delegated_method => "expected")
      subscription = Ashmont::Subscription.new(remote_subscription.id)
      result = subscription.send(delegated_method)
      Braintree::Subscription.should have_received(:find).with(remote_subscription.id)
      result.should == "expected"
    end
  end

  it "converts the next billing date into the configured timezone" do
    unconverted_date = "2011-01-20"
    remote_subscription = stub_remote_subscription(:next_billing_date => unconverted_date)
    subscription = Ashmont::Subscription.new("xyz")
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

  it "reloads the subscription after retrying a charge" do
    transaction = stub("transaction", :id => 'abc')
    retry_result = stub("retry-result", :transaction => transaction)
    settlement_result = stub("settlement-result", :success? => true)
    past_due_subscription = stub("subscription", :status => "past_due")
    active_subscription = stub("subscription", :status => "active")
    Braintree::Subscription.stubs(:retry_charge => retry_result)
    Braintree::Transaction.stubs(:submit_for_settlement => settlement_result)
    Braintree::Subscription.stubs(:find).returns(past_due_subscription).then.returns(active_subscription)

    subscription = Ashmont::Subscription.new('xyz')
    expect { subscription.retry_charge }.to change { subscription.status }.from("past_due").to("active")
  end

  it "updates a subscription" do
    token = 'xyz'
    Braintree::Subscription.stubs(:update => 'expected')

    subscription = Ashmont::Subscription.new(token)
    result = subscription.save(:name => "Billy")

    Braintree::Subscription.should have_received(:update).with(token, has_entries(:name => "Billy"))
    result.should == "expected"
  end

  it "creates a successful subscription" do
    attributes = { "test" => "hello" }
    remote_subscription = stub_remote_subscription(:status => "fine")
    result = stub("result", :subscription => remote_subscription, :success? => true)
    Braintree::Subscription.stubs(:create => result)

    subscription = Ashmont::Subscription.new
    subscription.save(attributes).should be_true

    Braintree::Subscription.should have_received(:create).with(has_entries(attributes))
    subscription.token.should == remote_subscription.id
    subscription.status.should == "fine"
  end

  it "passes a configured merchant account id" do
    remote_subscription = stub_remote_subscription(:id => "xyz", :status => "fine")
    result = stub("result", :subscription => remote_subscription, :success? => true)
    Braintree::Subscription.stubs(:create => result)

    with_configured_merchant_acount_id do |merchant_account_id|
      subscription = Ashmont::Subscription.new
      subscription.save({})

      Braintree::Subscription.should have_received(:create).with(has_entries(:merchant_account_id => merchant_account_id))
    end
  end

  it "doesn't pass a merchant account id when not is configured" do
    remote_subscription = stub_remote_subscription(:id => "xyz", :status => "fine")
    result = stub("result", :subscription => remote_subscription, :success? => true)
    Braintree::Subscription.stubs(:create => result)

    subscription = Ashmont::Subscription.new
    subscription.save({})

    Braintree::Subscription.should have_received(:create).with(has_entries(:merchant_account_id => nil)).never
  end

  it "returns the most recent transaction" do
    Timecop.freeze(Time.now) do
      dates = [2.days.ago, 3.days.ago, 1.day.ago]
      transactions = dates.map { |date| stub("transaction", :created_at => date) }
      remote_subscription = stub_remote_subscription(:transactions => transactions)

      subscription = Ashmont::Subscription.new("xyz")

      subscription.most_recent_transaction.created_at.should == 1.day.ago
    end
  end

  it "reloads remote data" do
    old_remote_subscription = stub_remote_subscription(:status => "old")
    new_remote_subscription = stub_remote_subscription(:status => "new")
    Braintree::Subscription.stubs(:find).returns(old_remote_subscription).then.returns(new_remote_subscription)
    subscription = Ashmont::Subscription.new(old_remote_subscription.id)
    subscription.status.should == "old"
    subscription.reload.status.should == "new"
  end

  it "finds status from the remote subscription" do
    remote_subscription = stub_remote_subscription(:status => "a-ok")
    subscription = Ashmont::Subscription.new("xyz")
    subscription.status.should == "a-ok"
  end

  it "doesn't have status without a remote subscription" do
    subscription = Ashmont::Subscription.new(nil)
    subscription.status.should be_nil
  end

  it "uses a cached status when provided" do
    remote_subscription = stub_remote_subscription(:status => "past-due")
    subscription = Ashmont::Subscription.new("xyz", :status => "a-ok")
    subscription.status.should == "a-ok"
  end

  it "updates the cached status when reloading" do
    remote_subscription = stub_remote_subscription(:status => "active")
    subscription = Ashmont::Subscription.new("xyz", :status => "past-due")
    subscription.reload
    subscription.status.should == "active"
  end

  def with_configured_merchant_acount_id
    merchant_account_id = "jkl"
    Ashmont.merchant_account_id = merchant_account_id
    yield merchant_account_id
  ensure
    Ashmont.merchant_account_id = nil
  end

  def stub_remote_subscription(options = {})
    stub(
      "remote_subscription",
      {
        :transactions => [],
        :status => "active",
        :id => "abcdef"
      }.update(options)
    ).tap { |subscription| Braintree::Subscription.stubs(:find => subscription) }
  end
end
