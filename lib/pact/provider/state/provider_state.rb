require 'pact/shared/dsl'
require 'pact/provider/state/provider_state_configured_modules'

module Pact
  module Provider::State

    BASE_PROVIDER_STATE_NAME = "__base_provider_state__"

    module DSL
      def provider_state name, &block
        ProviderStates.provider_state(name, &block).register
      end

      def set_up &block
        ProviderStates.base_provider_state.register.register_set_up &block
      end

      def tear_down &block
        ProviderStates.base_provider_state.register_tear_down &block
      end

      def provider_states_for name, &block
        ProviderStates.current_namespaces << name
        instance_eval(&block)
        ProviderStates.current_namespaces.pop
      end
    end

    class ProviderStates
      def self.provider_state name, &block
        ProviderState.build(name, current_namespaces.join('.'), &block)
      end

      def self.base_provider_state
        fullname = namespaced_name BASE_PROVIDER_STATE_NAME, {:for => current_namespaces.first }
        provider_states[fullname] ||= ProviderState.new(BASE_PROVIDER_STATE_NAME, current_namespaces.join('.'))
        provider_states[fullname]
      end

      def self.register name, provider_state
        provider_states[name] = provider_state
      end

      def self.provider_states
        @@provider_states ||= {}
      end

      def self.current_namespaces
        @@current_namespaces ||= []
      end

      def self.get name, options = {}
        fullname = namespaced_name name, options
        (provider_states[fullname] || provider_states[fullname.to_sym] || provider_states[name])
      end

      def self.get_base opts = {}
        fullname = namespaced_name BASE_PROVIDER_STATE_NAME, opts
        provider_states[fullname] || NoOpProviderState
      end

      def self.namespaced_name name, options = {}
        fullname = options[:for] ? "#{options[:for]}.#{name}" : name
      end
    end

    class ProviderState

      attr_accessor :name
      attr_accessor :namespace
      attr_accessor :provider_params

      extend Pact::DSL

      def initialize name, namespace, &block
        @name = name
        @namespace = namespace
        @set_up_defined = false
        @tear_down_defined = false
        @no_op_defined = false
        @provider_params = {}
      end

      def provider_param var_name, value
        @provider_params[var_name] = value
      end

      dsl do
        def set_up &block
          self.register_set_up &block
        end

        def tear_down &block
          self.register_tear_down &block
        end

        def no_op
          self.register_no_op
        end
      end

      def register
        ProviderStates.register(namespaced(name), self)
        self
      end

      def finalize
        validate
      end

      def register_set_up &block
        @set_up_block = block
        @set_up_defined = true
      end

      def register_tear_down &block
        @tear_down_block = block
        @tear_down_defined = true
      end

      def register_no_op
        @no_op_defined = true
      end

      def set_up
        if @set_up_block
          include_provider_state_configured_modules
          instance_eval &@set_up_block
        end
      end

      def tear_down
        if @tear_down_block
          include_provider_state_configured_modules
          instance_eval &@tear_down_block
        end
      end

      private

      attr_accessor :no_op_defined, :set_up_defined, :tear_down_defined

      def validate
        if no_op_defined && set_up_defined
          raise error_message_for_extra_block 'set_up'
        elsif no_op_defined && tear_down_defined
          raise error_message_for_extra_block 'tear_down'
        elsif !(no_op_defined || set_up_defined || tear_down_defined)
          raise "Please provide a set_up or tear_down block for provider state \"#{name}\". If there is no data to set up or tear down, you can use \"no_op\" instead."
        end
      end

      def error_message_for_extra_block block_name
        "Provider state \"#{name}\" has been defined as a no_op but it also has a #{block_name} block. Please remove one or the other."
      end

      def namespaced(name)
        if namespace.empty?
          name
        else
          "#{namespace}.#{name}"
        end
      end

      def include_provider_state_configured_modules
        # Doing this at runtime means the order of the Pact configuration block
        # and the provider state declarations doesn't matter.
        # Using include ProviderStateConfiguredModules on the class doesn't seem to work -
        # modules dynamically added to ProviderStateConfiguredModules don't seem to be
        # included in the including class.
        self.extend(ProviderStateConfiguredModules) unless self.singleton_class.ancestors.include?(ProviderStateConfiguredModules)
      end
    end

    class NoOpProviderState

      def self.set_up

      end

      def self.tear_down

      end

    end
  end
end
