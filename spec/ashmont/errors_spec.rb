require 'spec_helper'

describe Ashmont::Errors do
  it "adds an error for a declined number" do
    errors_for(:status => "processor_declined", :processor_response_text => "failure").
      should include("number was denied by the payment processor with the message: failure")
  end

  it "adds an error for a mismatched cvv" do
    errors_for(:status => "gateway_rejected").should include("cvv did not match")
  end

  it "adds a generic card number error" do
    errors_for(:messages => { :number => "Credit card number is unsupported" }).
      should include("number is unsupported")
  end

  it "adds a generic cvv error" do
    errors_for(:messages => { :CVV => "CVV is unsupported" }).
      should include("cvv is unsupported")
  end

  it "adds a generic expiration_month error" do
    errors_for(:messages => { :expiration_month => "Expiration month is unsupported" }).
      should include("expiration_month is unsupported")
  end

  it "adds a generic expiration_year error" do
    errors_for(:messages => { :expiration_year => "Expiration year is unsupported" }).
      should include("expiration_year is unsupported")
  end

  it "handles error results without a status" do
    result = {}
    errors = [ stub("error", :attribute => "foo", :message => "bar") ]
    expect { Ashmont::Errors.new(result, errors).to_hash }.to_not raise_error(NoMethodError)
  end

  def errors_for(options = {})
    result = stub("result",
                  :status => options[:status] || "rejected",
                  :processor_response_text => options[:processor_response_text] || "error")
    errors = (options[:messages] || {}).map do |attribute, message|
      stub("error", :attribute => attribute.to_s, :message => message)
    end

    Ashmont::Errors.new(result, errors).to_hash.inject([]) do |result, (attribute, message)|
      result << [attribute, message].join(" ")
    end
  end
end
