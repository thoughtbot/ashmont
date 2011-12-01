require "ashmont/version"
require "ashmont/subscription"

module Ashmont
  class << self
    attr_accessor :merchant_account_time_zone
  end

  self.merchant_account_time_zone = 'Eastern Time (US & Canada)'
end
