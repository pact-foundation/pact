require 'open-uri'
require 'pact/consumer_contract'
require 'pact/provider/rspec/matchers'
require 'pact/provider/test_methods'
require 'pact/provider/configuration'
require 'pact/provider/matchers/messages'


module Pact
  module Provider
    module RSpec

      module InstanceMethods
        def app
          Pact.configuration.provider.app
        end
      end

      module ClassMethods
        EMPTY_ARRAY = [].freeze

        include ::RSpec::Core::DSL

        def honour_pactfile pact_source, pact_json, options
          pact_uri = pact_source.uri
          Pact.configuration.output_stream.puts "INFO: Reading pact at #{pact_uri}"
          consumer_contract = Pact::ConsumerContract.from_json(pact_json)
        
          suffix = pact_uri.metadata[:pending] ? " [PENDING]": ""
          example_group_description = "Verifying a pact between #{consumer_contract.consumer.name} and #{consumer_contract.provider.name}#{suffix}"
          example_group_metadata = { pactfile_uri: pact_uri, pact_criteria: options[:criteria] }

          ::RSpec.describe example_group_description, example_group_metadata do
            honour_consumer_contract consumer_contract, options.merge(
              pact_json: pact_json,
              pact_uri: pact_uri,
              pact_source: pact_source,
              consumer_contract: consumer_contract,
              criteria: options[:criteria]
            )
          end
        end

        def honour_consumer_contract consumer_contract, options = {}
          describe_consumer_contract consumer_contract, options.merge(consumer: consumer_contract.consumer.name, pact_context: InteractionContext.new)
        end

        private

        def describe_consumer_contract consumer_contract, options
          consumer_interactions(consumer_contract, options).tap{ |interactions|
            if interactions.empty?
              # If there are no interactions, the documentation formatter never fires to print this out,
              # so print it out here.
              Pact.configuration.output_stream.puts "DEBUG: All interactions for #{options[:pact_uri]} have been filtered out by criteria: #{options[:criteria]}" if options[:criteria] && options[:criteria].any?
            end
          }.each do |interaction|
            describe_interaction_with_provider_state interaction, options
          end
        end

        def consumer_interactions(consumer_contract, options)
          if options[:criteria].nil?
            consumer_contract.interactions
          else
            consumer_contract.find_interactions(options[:criteria])
          end
        end

        def describe_interaction_with_provider_state interaction, options
          if interaction.provider_state
            describe "Given #{interaction.provider_state}" do
              describe_interaction interaction, options
            end
          else
            describe_interaction interaction, options
          end
        end

        def describe_interaction interaction, options
          # pact_uri and pact_interaction are used by
          # Pact::Provider::RSpec::PactBrokerFormatter

          # pact_interaction_example_description is used by
          # Pact::Provider::RSpec::Formatter and Pact::Provider::RSpec::Formatter2

          # pact: verify is used to allow RSpec before and after hooks.
          metadata = {
            pact: :verify,
            pact_interaction: interaction,
            pact_interaction_example_description: interaction_description_for_rerun_command(interaction),
            pact_uri: options[:pact_uri],
            pact_source: options[:pact_source],
            pact_ignore_failures: options[:pact_source].pending? || options[:ignore_failures],
            pact_consumer_contract: options[:consumer_contract]
          }

          describe description_for(interaction), metadata do

            interaction_context = InteractionContext.new
            pact_context = options[:pact_context]

            before do | example |
              interaction_context.run_once :before do
                Pact.configuration.logger.info "Running example '#{Pact::RSpec.full_description(example)}'"
                state_params = set_up_provider_states interaction.provider_states, options[:consumer]
                interaction_context.state_params = state_params
                replay_interaction interaction, options[:request_customizer], interaction_context
                interaction_context.last_response = last_response
              end
            end

            after do
              interaction_context.run_once :after do
                tear_down_provider_states interaction.provider_states, options[:consumer]
              end
            end

            if interaction.respond_to?(:message?) && interaction.message?
              describe_message Pact::Response.new(interaction.response), interaction_context
            else
              describe "with #{interaction.request.method_and_path}" do
                describe_response Pact::Response.new(interaction.response), interaction_context
              end
            end
          end
        end

        def describe_message expected_response, interaction_context
          include Pact::RSpec::Matchers
          extend Pact::Matchers::Messages


          let(:expected_contents) { expected_response.body[:contents].as_json }
          let(:response) { interaction_context.last_response }
          let(:differ) { Pact.configuration.body_differ_for_content_type diff_content_type }
          let(:diff_formatter) { Pact.configuration.diff_formatter_for_content_type diff_content_type }
          let(:diff_options) { { with: differ, diff_formatter: diff_formatter } }
          let(:diff_content_type) { 'application/json' }
          let(:response_body) { parse_body_from_response(response) }
          let(:actual_contents) { response_body['contents'] }

          it "has matching content" do | example |
            if response.status != 200
              raise "An error was raised while verifying the message. The response body is: #{response.body}"
            end
            set_metadata(example, :pact_actual_contents, actual_contents)
            expect(actual_contents).to match_term expected_contents, diff_options, example
          end
        end

        def describe_response expected_response, interaction_context

          describe "returns a response which" do

            include Pact::RSpec::Matchers
            extend Pact::Matchers::Messages

            let(:expected_response_status) { expected_response.status }
            let(:expected_response_body) { expected_response.body }
            let(:response) { interaction_context.last_response }
            let(:response_status) { response.status }
            let(:response_body) { parse_body_from_response(response) }
            let(:differ) { Pact.configuration.body_differ_for_content_type diff_content_type }
            let(:diff_formatter) { Pact.configuration.diff_formatter_for_content_type diff_content_type }
            let(:expected_content_type) { Pact::Headers.new(expected_response.headers || {})['Content-Type'] }
            let(:actual_content_type) { response.headers['Content-Type']}
            let(:diff_content_type) { String === expected_content_type ? expected_content_type : actual_content_type } # expected_content_type may be a Regexp
            let(:diff_options) { { with: differ, diff_formatter: diff_formatter } }

            if expected_response.status
              it "has status code #{expected_response.status}" do | example |
                set_metadata(example, :pact_actual_status, response_status)
                expect(response_status).to eql expected_response_status
              end
            end

            if expected_response.headers
              describe "includes headers" do
                expected_response.headers.each do |name, expected_header_value|
                  it "\"#{name}\" which #{expected_desc_for_it(expected_header_value)}" do  | example |
                    set_metadata(example, :pact_actual_headers, response.headers)
                    header_value = response.headers[name]
                    expect(header_value).to match_header(name, expected_header_value)
                  end
                end
              end
            end

            if expected_response.body
              it "has a matching body" do | example |
                set_metadata(example, :pact_actual_body, response_body)
                expect(response_body).to match_term expected_response_body, diff_options, example
              end
            end
          end
        end

        def description_for interaction
          interaction.provider_state ? interaction.description : interaction.description.capitalize
        end

        def interaction_description_for_rerun_command interaction
          description_for(interaction).capitalize + ( interaction.provider_state ? " given #{interaction.provider_state}" : "")
        end
      end

      # The "arrange" and "act" parts of the test really only need to be run once,
      # however, stubbing is not supported in before :all, so this is a
      # wee hack to enable before :all like functionality using before :each.
      # In an ideal world, the test setup and execution should be quick enough for
      # the difference between :all and :each to be unnoticable, but the annoying
      # reality is, sometimes it does make a difference. This is for you, V!

      class InteractionContext

        attr_accessor :last_response

        attr_accessor :state_params

        def initialize
          @already_run = []
        end

        def run_once hook
          unless @already_run.include?(hook)
            yield
            @already_run << hook
          end
        end

      end
    end
  end
end

