Ashmont
=======

Ashmont is a set of classes that make it easier to use
[Braintree payment processing](http://www.braintreepayments.com/) in a Rails application.

Ashmont attempts to make the following tasks easier:

* Processing error messages from Braintree and using them in the ActiveModel API
* Delegating and caching relevant information in a model backed by a Braintree
  recurring subscription
* Delegating and caching relevant information in a model backed by a Braintree
  customer with a credit card
* Determining what actions are necessary to handle a form update, such as
  updating a credit card, switching subscription plans, or retrying failed
  subscription transactions

Ashmont is still an early work in progress and the API may change dramatically with each release.

Installation
------------

In your Gemfile:

    gem "ashmont"

If you have an account with Braintree with multiple merchant accounts you'll
want to configure the merchant account for this application:

    Ashmont.merchant_account_id = 'your merchant account id'

Ashmont converts billing dates from Braintree into TimeWithZone instances to
avoid time zone mishaps. You'll want to configure Ashmont with the correct
timezone so that billing dates end up on the correct day.

    Ashmont.merchant_account_time_zone = 'Eastern Time (US & Canada)'

Usage
-----

In order to process payments with Braintree, you'll want to store customer and
subscription tokens locally. You'll also need to store the billing status next
billing date in order to synchronize account status with Braintree.

    create_table "users" do |t|
      t.string   "customer_token"
      t.string   "subscription_token"
      t.datetime "next_billing_date"
      t.string   "subscription_status"
    end

Here's a simple example for creating and updating a subscribed customer:

    class User < ActiveRecord::Base
      before_create :create_customer
      after_destroy :destroy_customer
      memoize :customer

      def past_due?
        customer.past_due?
      end

      def save_customer(attributes)
        customer.save(attributes)
      end

      private

      def create_customer
        save_customer(:email => email)
        if customer.save(:email => email)
          self.customer_token = customer.token
          self.subscription_token = customer.subscription_token
          self.next_billing_date = customer.next_billing_date
          self.subscription_status = customer.status
          true
        else
          copy_errors customer.errors
          false
        end
      end

      def destroy_customer
        customer.delete
      end

      def copy_errors(source_errors)
        source_errors.to_hash.each do |attribute, messages|
          errors.set(attribute, messages)
        end
      end

      def customer
        Ashmont::SubscribedCustomer.new(
          Ashmont::Customer.new(customer_token),
          Ashmont::Subscription.new(subscription_token, :status => subscription_status)
        )
      end
    end

    user = User.new(params[:user])
    user.save_customer(params[:customer])

The above `save_customer` method will accept attributes related to
subscriptions, customrers, and credit cards.

Testing
-------

We recommend testing your applications using the
[fake_braintree](https://github.com/thoughtbot/fake_braintree) library, which
allows applications to use the real Braintree API without actually hitting
Braintree's servers during automated tests.

License
-------

Ashmont is Copyright © 2011 thoughtbot. It is free software, and may be
redistributed under the terms specified in the LICENSE file.
