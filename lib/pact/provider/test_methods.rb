require 'pact/logging'
require 'rack/test'
require 'pact/consumer_contract/interaction'
require 'pact/provider/state/provider_state'
require 'pact/provider/state/provider_state_proxy'
require 'pact/provider/request'
require 'pact/provider/world'
require 'pact/provider/state/provider_state_manager'

module Pact
  module Provider
    module TestMethods

      include Pact::Logging
      include Rack::Test::Methods

      def replay_interaction interaction, request_customizer = nil, interaction_context
        request = Request::Replayable.new(interaction.request, interaction_context)
        request = request_customizer.call(request, interaction) if request_customizer
        args = [request.path, request.body, request.headers]

        logger.info "Sending #{request.method.upcase} request to path: \"#{request.path}\" with headers: #{request.headers}, see debug logs for body"
        logger.debug "body :#{request.body}"
        response = if self.respond_to?(:custom_request)
          self.custom_request(request.method.upcase, *args)
        else
          self.send(request.method.downcase, *args)
        end
        logger.info "Received response with status: #{response.status}, headers: #{response.headers}, see debug logs for body"
        logger.debug "body: #{response.body}"
      end

      def parse_body_from_response rack_response
        case rack_response.headers['Content-Type']
        when /json/
          # For https://github.com/pact-foundation/pact-net/issues/237
          # Only required for the pact-ruby-standalone ¯\_(ツ)_/¯
          JSON.load("[#{rack_response.body}]").first
        else
          rack_response.body
        end
      end

      def set_up_provider_states provider_states, consumer, options = {}
        state_params = {};
        # If there are no provider state, execute with an nil state to ensure global and base states are executed
        Pact.configuration.provider_state_set_up.call(nil, consumer, options) if provider_states.nil? || provider_states.empty?
        provider_states.each do | provider_state |
          result = Pact.configuration.provider_state_set_up.call(provider_state.name, consumer, options.merge(params: provider_state.params))
          if result.is_a?(Hash)
            state_params = state_params.merge(result)
          end
        end

        state_params
      end

      def tear_down_provider_states provider_states, consumer, options = {}
        # If there are no provider state, execute with an nil state to ensure global and base states are executed
        Pact.configuration.provider_state_tear_down.call(nil, consumer, options) if provider_states.nil? || provider_states.empty?
        provider_states.reverse_each do | provider_state |
          Pact.configuration.provider_state_tear_down.call(provider_state.name, consumer, options.merge(params: provider_state.params))
        end
      end

      def set_metadata example, key, value
        Pact::RSpec.with_rspec_3 do
          example.metadata[key] = value
        end

        Pact::RSpec.with_rspec_2 do
          example.example.metadata[key] = value
        end
      end
    end
  end
end
