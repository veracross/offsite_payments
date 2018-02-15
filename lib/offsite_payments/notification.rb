module OffsitePayments #:nodoc:
  class Notification
    attr_accessor :params
    attr_accessor :raw

    # set this to an array in the subclass, to specify which IPs are allowed
    # to send requests
    class_attribute :production_ips

    # * *Args*    :
    #   - +doc+ ->     raw post string
    #   - +options+ -> custom options which individual implementations can
    #                  utilize
    def initialize(post, options = {})
      @options = options
      empty!
      parse(post)
    end

    def status
      raise NotImplementedError, "Must implement this method in the subclass"
    end

    # the money amount we received in X.2 decimal.
    def gross
      raise NotImplementedError, "Must implement this method in the subclass"
    end

    def gross_cents
      (gross.to_f * 100.0).round
    end

    def amount
      amount = gross ? gross.to_d : 0
      return Money.from_amount(amount, currency) rescue ArgumentError
      return Money.from_amount(amount) # maybe you have an own money object which doesn't take a currency?
    end

    # reset the notification.
    def empty!
      @params  = Hash.new
      @raw     = ""
    end

    # Check if the request comes from an official IP
    def valid_sender?(ip)
      return true if OffsitePayments.mode == :test || production_ips.blank?
      production_ips.include?(ip)
    end

    def test?
      false
    end

    def iso_currency
      ActiveUtils::CurrencyCode.standardize(currency)
    end

    private

    # Take the posted data and move the relevant data into a hash
    def parse(post)
      @raw = post.to_s
      for line in @raw.split('&')
        key, value = *line.scan( %r{^([A-Za-z0-9_.-]+)\=(.*)$} ).flatten
        params[key] = CGI.unescape(value.to_s) if key.present?
      end
    end
  end
end
