require 'spec_helper'

describe Ashmont::SubscribedCustomer do
  it "delegates Customer methods to the customer" do
    customer = stub("customer")
    subscribed_customer = build_subscribed_customer(:customer => customer)
    customer_methods = Ashmont::Customer.instance_methods(false)
    merged_methods = [:errors, :save]
    delegated_methods = customer_methods - merged_methods
    delegated_methods.each do |method|
      customer.stubs(method => "expected")
      result = subscribed_customer.send(method, "argument")
      customer.should have_received(method).with("argument")
      result.should == "expected"
    end
  end

  it "delegates some Subscription methods to the subscription" do
    subscription = stub("subscription")
    subscribed_customer = build_subscribed_customer(:subscription => subscription)
    %w(reload status next_billing_date transactions most_recent_transaction retry_charge past_due?).each do |method|
      subscription.stubs(method => "expected")
      result = subscribed_customer.send(method, "argument")
      subscription.should have_received(method).with("argument")
      result.should == "expected"
    end
  end

  it "delegates #subscription_token to its subscription's token" do
    subscription = stub("subscription", :token => "expected")
    subscribed_customer = build_subscribed_customer(:subscription => subscription)
    subscribed_customer.subscription_token.should == "expected"
  end

  it "#reloads the subscription" do
    subscription = stub("subscription", :reload => "expected")
    subscribed_customer = build_subscribed_customer(:subscription => subscription)

    result = subscribed_customer.reload

    subscription.should have_received(:reload)
    result.should == "expected"
  end

  it "can #save the customer" do
    attributes = { :email => "somebody@example.com" }
    customer = stub("customer", :save => true, :token => nil)
    subscribed_customer = build_subscribed_customer(:customer => customer)

    result = subscribed_customer.save(attributes)

    customer.should have_received(:save).with(attributes)
    result.should be_true
  end

  it "saves a new customer without attributes" do
    customer = stub("customer", :token => nil, :save => true)
    subscribed_customer = build_subscribed_customer(:customer => customer)

    subscribed_customer.save({})

    customer.should have_received(:save).with({})
  end

  it "doesn't #save the customer without any customer attributes" do
    attributes = { :price => 49 }
    customer = stub("customer", :save => true, :token => "xyz")
    subscribed_customer = build_subscribed_customer(:customer => customer)

    subscribed_customer.save(attributes)

    customer.should have_received(:save).never
  end

  it "can #save the subscription" do
    attributes = { :plan_id => 41, :price => 15 }
    subscription = stub("subscription", :save => "expected", :past_due? => false)
    payment_method_token = "xyz"
    customer = stub("customer", :payment_method_token => payment_method_token, :token => "xyz")
    subscribed_customer = build_subscribed_customer(:subscription => subscription, :customer => customer)

    result = subscribed_customer.save(attributes)

    subscription.should have_received(:save).with(:plan_id => 41, :price => "15", :payment_method_token => payment_method_token)
    result.should == "expected"
  end

  it "retries the subscription when past due" do
    subscription = stub("subscription", :past_due? => true, :retry_charge => true)

    subscribed_customer = build_subscribed_customer(:subscription => subscription)
    subscribed_customer.save({})

    subscription.should have_received(:retry_charge)
  end

  it "merges #errors from the customer and subscription" do
    subscription = stub("subscription", :errors => stub_errors("one" => "first"))
    customer = stub("customer", :errors => stub_errors("two" => "second"))
    subscribed_customer = build_subscribed_customer(:subscription => subscription, :customer => customer)

    subscribed_customer.errors.to_hash.should == { "one" => "first", "two" => "second" }
  end

  def build_subscribed_customer(options = {})
    Ashmont::SubscribedCustomer.new(
      options[:customer] || build_customer,
      options[:subscription] || build_subscription
    )
  end

  def build_customer
    Ashmont::Customer.new("xyz")
  end

  def build_subscription
    Ashmont::Subscription.new("abc", :status => "Active")
  end

  def stub_errors(messages)
    stub("errors", :to_hash => messages)
  end
end
