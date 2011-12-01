module Ashmont
  class Errors
    ERROR_MESSAGE_PREFIXES = {
      "number" => "Credit card number ",
      "CVV" => "CVV ",
      "expiration_month" => "Expiration month ",
      "expiration_year" => "Expiration year "
    }

    def initialize(result, remote_errors)
      @errors = {}
      parse_result(result)
      parse_remote_errors(remote_errors)
    end

    def to_hash
      @errors.dup
    end

    private

    def parse_result(result)
      case result.status
      when "processor_declined"
        add_error :number, "was denied by the payment processor with the message: #{result.processor_response_text}"
      when "gateway_rejected"
        add_error :cvv, "did not match"
      end
    end

    def parse_remote_errors(remote_errors)
      remote_errors.each do |error|
        if prefix = ERROR_MESSAGE_PREFIXES[error.attribute]
          message = error.message.sub(prefix, "")
          add_error error.attribute.downcase, message
        end
      end
    end

    def add_error(attribute, message)
      @errors[attribute] ||= []
      @errors[attribute] << message
    end
  end
end
