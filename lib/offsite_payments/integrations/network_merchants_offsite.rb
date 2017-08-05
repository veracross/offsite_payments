module OffsitePayments #:nodoc:
  module Integrations #:nodoc:
    module NetworkMerchantsOffsite
      mattr_accessor :production_url
      mattr_accessor :test_url
      self.production_url = 'https://secure.networkmerchants.com/api/v2/three-step'
      self.test_url       = 'https://secure.networkmerchants.com/api/v2/three-step'

      def self.helper(order, account, options={})
        Helper.new(order, account, options)
      end

      def self.notification(query_string, options={})
        Notification.new(query_string, options)
      end

      def self.return(query_string, options={})
        Return.new(query_string, options)
      end

      def self.service_url
        mode = OffsitePayments.mode
        case mode
        when :production
          self.production_url
        when :test
          self.test_url
        else
          raise StandardError, "Integration mode set to an invalid value: #{mode}"
        end
      end

      module Common
        CURRENCY_SPECIAL_MINOR_UNITS = {
          'BIF' => 0,
          'BYR' => 0,
          'CLF' => 0,
          'CLP' => 0,
          'CVE' => 0,
          'DJF' => 0,
          'GNF' => 0,
          'HUF' => 0,
          'ISK' => 0,
          'JPY' => 0,
          'KMF' => 0,
          'KRW' => 0,
          'PYG' => 0,
          'RWF' => 0,
          'UGX' => 0,
          'UYI' => 0,
          'VND' => 0,
          'VUV' => 0,
          'XAF' => 0,
          'XOF' => 0,
          'XPF' => 0,
          'BHD' => 3,
          'IQD' => 3,
          'JOD' => 3,
          'KWD' => 3,
          'LYD' => 3,
          'OMR' => 3,
          'TND' => 3,
          'COU' => 4
        }

        def create_signature(fields, secret)
          data = fields.join('.')
          digest = Digest::SHA1.hexdigest(data)
          signed = "#{digest}.#{secret}"
          Digest::SHA1.hexdigest(signed)
        end

        # Realex accepts currency amounts as an integer in the lowest value
        # e.g.
        #     format_amount(110.56, 'GBP')
        #     => 11056
        def format_amount(amount, currency)
          if amount.is_a? Float
            units = CURRENCY_SPECIAL_MINOR_UNITS[currency] || 2
            multiple = 10**units
            return (amount.to_f * multiple.to_f).to_i
          else
            return amount
          end
        end

        # Realex returns currency amount as an integer
        def format_amount_as_float(amount, currency)
          units = CURRENCY_SPECIAL_MINOR_UNITS[currency] || 2
          divisor = 10**units
          return (amount.to_f / divisor.to_f)
        end

        def extract_digits(value)
          value.scan(/\d+/).join('')
        end

        def extract_avs_code(params={})
          [extract_digits(params[:zip]), extract_digits(params[:address1])].join('|')
        end

      end

      class Helper < OffsitePayments::Helper
        include Common

        def initialize(order, account, options = {})
          @timestamp   = Time.now.strftime('%Y%m%d%H%M%S')
          @currency    = options[:currency]
          @merchant_id = account
          @sub_account = options[:credential2]
          @secret      = options[:credential3]
          super
          add_field 'currency', @currency
        end

        def form_fields
          {'api-toke' => @merchant_id, 'amount' => :amount}
        end

        def amount=(amount)
          add_field 'amount', format_amount(amount, @currency)
        end

        def billing_address(params={})
          add_field(mappings[:billing_address][:zip], extract_avs_code(params))
          add_field(mappings[:billing_address][:country], lookup_country_code(params[:country]))
        end

        def shipping_address(params={})
          add_field(mappings[:shipping_address][:zip], extract_avs_code(params))
          add_field(mappings[:shipping_address][:country], lookup_country_code(params[:country]))
        end

        mapping :currency,         'currency'
        mapping :order,            'order-id'
        mapping :amount,           'amount'
        mapping :return_url,       'redirect-url,'
        mapping :customer,         :email => 'email'
        mapping :shipping_address, :zip =>        'postal',
                                   :country =>    'country'
        mapping :billing_address,  :zip =>        'postal',
                                   :country =>    'country'
      end

      class Notification < OffsitePayments::Notification
        include Common
        def initialize(post, options={})
          super
          @secret = options[:credential3]
        end
      end

      class Return < OffsitePayments::Return
        def initialize(data, options)
          super
          @notification = Notification.new(data, options)
        end

        def success?
          notification.complete?
        end

        # TODO: realex does not provide a separate cancelled endpoint
        def cancelled?
          false
        end

        def message
          notification.message
        end
      end

    end
  end
end
