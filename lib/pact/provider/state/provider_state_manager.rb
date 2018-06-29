module Pact
  module Provider::State
    class ProviderStateManager

      attr_reader :provider_state_name, :consumer

      def initialize provider_state_name, consumer
        @provider_state_name = provider_state_name
        @consumer = consumer
      end

      def set_up_provider_state
        get_global_base_provider_state.set_up
        get_consumer_base_provider_state.set_up
        if provider_state_name
          provider_state = get_provider_state
          provider_state.set_up
          return provider_state.provider_params
        end
        return {}
      end

      def tear_down_provider_state
        if provider_state_name
          get_provider_state.tear_down
        end
        get_consumer_base_provider_state.tear_down
        get_global_base_provider_state.tear_down
      end

      def get_provider_state
        Pact.provider_world.provider_states.get(provider_state_name, :for => consumer)
      end

      def get_consumer_base_provider_state
        Pact.provider_world.provider_states.get_base(:for => consumer)
      end

      def get_global_base_provider_state
        Pact.provider_world.provider_states.get_base
      end

    end
  end
end