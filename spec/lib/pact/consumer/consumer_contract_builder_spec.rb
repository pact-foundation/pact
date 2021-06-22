require 'spec_helper'
require 'fileutils'
require 'pathname'

module Pact
  module Consumer
    describe ConsumerContractBuilder do

      let(:consumer_name) { 'a consumer' }
      let(:provider_name) { 'a provider' }
      let(:pact_dir) { './spec/pacts' }

      subject do
        Pact::Consumer::ConsumerContractBuilder.new(
          consumer_name: consumer_name,
          provider_name: provider_name,
          pactfile_write_mode: :overwrite,
          port: 2222,
          host: 'localhost',
          pact_dir: pact_dir)
      end

      describe "#handle_interaction_fully_defined" do

        let(:interaction_hash) {
          {
            description: 'Test request',
            request: {
              method: 'post',
              path: '/foo',
              body: Term.new(generate: 'waffle', matcher: /ffl/),
              headers: { 'Content-Type' => 'application/json' },
              query: "",
            },
            response: {
              baz: 'qux',
              wiffle: 'wiffle'
            }
          }
        }

        let(:interaction_json) { {} }

        let(:interaction) { Pact::Interaction.from_hash(JSON.load(interaction_hash.to_json)) }

        before do
          stub_request(:post, 'localhost:2222/interactions')
        end

        it "posts the interaction with generated response to the mock service" do
          subject.handle_interaction_fully_defined interaction
          expect(WebMock).to have_requested(:post, 'localhost:2222/interactions').with(body: interaction_json)
        end

        it "resets the interaction_builder to nil" do
          expect(subject).to receive(:interaction_builder=).with(nil)
          subject.handle_interaction_fully_defined interaction
        end

        it "validates the interaction" do
          expect(interaction).to receive(:validate!)
          subject.handle_interaction_fully_defined(interaction)
        end
      end

      describe "#consumer_contract" do
        it "returns the consumer contract" do
      		expect(subject.consumer_contract).to eq(
            consumer: { name: consumer_name },
            provider: { name: provider_name },
            pactfile_write_mode: 'overwrite',
            pact_dir: pact_dir
          )
      	end
      end

      describe "#mock_service_base_url" do

      	subject do
      		ConsumerContractBuilder.new(
      			pactfile_write_mode: :overwrite,
            pact_dir: './spec/pacts',
            consumer_name: consumer_name,
            provider_name: provider_name,
            host: 'localhost',
        		port: 1234
          )
        end

      	it "returns the mock service base URL" do
      		expect(subject.mock_service_base_url).to eq("http://localhost:1234")
      	end
      end

      describe "#write_pact" do

        let(:body) do
          {
            consumer: { name: consumer_name },
            provider: { name: provider_name },
            pactfile_write_mode: "overwrite",
            pact_dir: pact_dir
          }
        end

        it "posts the pact details to the mock service" do
          allow_any_instance_of(Pact::MockService::Client).to receive(:write_pact).with(body)
          subject.write_pact
        end
      end
    end
  end
end
