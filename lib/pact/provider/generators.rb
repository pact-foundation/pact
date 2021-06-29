
require 'pact/provider/generators/provider_state';

module Pact
  module Provider  
    class Generators
      def self.add_generator generator
        generators.unshift(generator)
      end

      def self.generators
        @generators ||= []
      end

      def self.execute_generators object, interaction_context = nil
        generators.each do | parser |
          return parser.call(object, interaction_context) if parser.can_generate?(object)
        end
        
        raise Pact::UnrecognizePactFormatError.new("This document does not use a recognised Pact generator: #{object}")
      end

      add_generator(ProviderStateGenerator.new)
    end
  end
end
