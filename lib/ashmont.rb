require "ashmont/version"
require "ashmont/subscription"
require "ashmont/customer"
require "ashmont/subscribed_customer"

module Ashmont
  class << self
    attr_accessor :merchant_account_time_zone
    attr_accessor :merchant_account_id
  end

  self.merchant_account_time_zone = 'Eastern Time (US & Canada)'
end
