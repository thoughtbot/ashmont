require "ashmont/version"
require "ashmont/subscription"
require "ashmont/customer"

module Ashmont
  class << self
    attr_accessor :merchant_account_time_zone
  end

  self.merchant_account_time_zone = 'Eastern Time (US & Canada)'
end
