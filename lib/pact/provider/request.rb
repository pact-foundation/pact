require 'json'
require 'pact/reification'
require 'pact/shared/null_expectation'
require 'pact/provider/generators'

module Pact
  module Provider
    module Request
      class Replayable

        # See https://github.com/rack/rack/blob/e7d741c6282ca4cf4e01506f5681e6e6b14c0b32/SPEC#L87-89
        NO_HTTP_PREFIX = ["CONTENT-TYPE", "CONTENT-LENGTH"]

        def initialize expected_request, interaction_context = nil
          @expected_request = expected_request
          @interaction_context = interaction_context
        end

        def method
          expected_request.method
        end

        def path
          if expected_request.methods.include? :generators
            if expected_request.generators["path"]
              return Pact::Provider::Generators.execute_generators(expected_request.generators["path"], @interaction_context)
            end
          end
          expected_request.full_path
        end

        def body
          case expected_request.body
          when String then expected_request.body
          when NullExpectation then ''
          else
            reified_body
          end
        end

        def headers
          request_headers = {}
          return request_headers if expected_request.headers.is_a?(Pact::NullExpectation)
          expected_request.headers.each do |key, value|
            request_headers[rack_request_header_for(key)] = Pact::Reification.from_term(value)
          end
          request_headers
        end

        private

        attr_reader :expected_request

        def reified_body
          rb = Pact::Reification.from_term(expected_request.body)
          if rb.is_a?(String)
            rb
          else
            JSON.dump(rb)
          end
        end

        def rack_request_header_for header
          with_http_prefix(header.to_s.upcase).tr('-', '_')
        end

        def rack_request_value_for value
          Array(value).join("\n")
        end

        def with_http_prefix header
          NO_HTTP_PREFIX.include?(header) ? header : "HTTP_#{header}"
        end
      end
    end
  end
end
