require 'pact/provider/generators'

module Pact
  module Provider
    class ProviderStateGenerator

      
      # rewrite of https://github.com/DiUS/pact-jvm/blob/master/core/support/src/main/kotlin/au/com/dius/pact/core/support/expressions/ExpressionParser.kt#L27
      VALUES_SEPARATOR = ","
      START_EXPRESSION = "\${"
      END_EXPRESSION = '}'
      def parse_expression expression, params 
        
        return_string = []

        buffer = expression;
        # initial value
        position = buffer.index(START_EXPRESSION)
        
        while (position && position >= 0) 
          if (position > 0) 
            # add string 
            return_string.push(buffer[0...position])
          end
          end_position = buffer.index(END_EXPRESSION, position)
          if (end_position < 0)
            raise "Missing closing brace in expression string \"#{$value}\""
          end

          variable = ""

          if (end_position - position > 2)
            expression = params[buffer[position+2...end_position]] || ""
          end
          return_string.push(expression)
          
          buffer = buffer[end_position + 1...-1]
          position = buffer.index(START_EXPRESSION)
        end

        return_string.join("")
      end

      def call hash, interaction_context = nil
        params = interaction_context.state_params || {}

        parse_expression hash["expression"], params
      end

      def can_generate?(hash)
        hash.key?('type') && hash['type'] === 'ProviderState'
      end
    end
  end
end



