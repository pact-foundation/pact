require 'pact/provider/configuration/pact_verification'

module Pact
  module Provider
    module Configuration
      describe PactVerificationFromBroker do
        describe 'build' do
          let(:provider_name) {'provider-name'}
          let(:provider_version_tags) { ['master'] }
          let(:base_url) { "http://broker.org" }
          let(:basic_auth_options) do
            {
              username: 'pact_broker_username',
              password: 'pact_broker_password'
            }
          end
          let(:tags) { ['master'] }

          before do
            allow(Pact::PactBroker::FetchPactsForVerification).to receive(:new).and_return(fetch_pacts)
            allow(Pact.provider_world).to receive(:add_pact_uri_source)
          end

          context "with valid values" do
            subject do
              PactVerificationFromBroker.build(provider_name, provider_version_tags) do
                pact_broker_base_url base_url, basic_auth_options
                consumer_version_tags tags
                verbose true
              end
            end

            let(:fetch_pacts) { double('FetchPacts') }
            let(:options) { basic_auth_options.merge(verbose: true) }
            let(:consumer_version_selectors) { [ { tag: 'master', latest: true }] }

            it "creates a instance of Pact::PactBroker::FetchPactsForVerification" do
              expect(Pact::PactBroker::FetchPactsForVerification).to receive(:new).with(provider_name, consumer_version_selectors, provider_version_tags, base_url, options)
              subject
            end

            it "adds a pact_uri_source to the provider world" do
              expect(Pact.provider_world).to receive(:add_pact_uri_source).with(fetch_pacts)
              subject
            end
          end

          context "with a missing base url" do
            subject do
              PactVerificationFromBroker.build(provider_name, provider_version_tags) do

              end
            end

            let(:fetch_pacts) { double('FetchPacts') }

            it "raises an error" do
              expect { subject }.to raise_error Pact::Error, /Please provide a pact_broker_base_url/
            end
          end

          context "with a non array object for consumer_version_tags" do
            subject do
              PactVerificationFromBroker.build(provider_name, provider_version_tags) do
                pact_broker_base_url base_url
                consumer_version_tags "master"
              end
            end

            let(:fetch_pacts) { double('FetchPacts') }

            it "coerces the value into an array" do
              expect(Pact::PactBroker::FetchPactsForVerification).to receive(:new).with(anything, [{ tag: "master", latest: true}], anything, anything, anything)
              subject
            end
          end

          context "when no consumer_version_tags are provided" do
            subject do
              PactVerificationFromBroker.build(provider_name, provider_version_tags) do
                pact_broker_base_url base_url
              end
            end

            let(:fetch_pacts) { double('FetchPacts') }

            it "creates an instance of FetchPacts with an emtpy array for the consumer_version_tags" do
              expect(Pact::PactBroker::FetchPactsForVerification).to receive(:new).with(anything, [], anything, anything, anything)
              subject
            end
          end

          context "when no verbose flag is provided" do
            subject do
              PactVerificationFromBroker.build(provider_name, provider_version_tags) do
                pact_broker_base_url base_url
              end
            end

            let(:fetch_pacts) { double('FetchPacts') }

            it "creates an instance of FetchPactsForVerification with verbose: false" do
              expect(Pact::PactBroker::FetchPactsForVerification).to receive(:new).with(anything, anything, anything, anything, hash_including(verbose: false))
              subject
            end
          end
        end
      end
    end
  end
end
