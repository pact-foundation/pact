require 'spec_helper'
require 'pact/provider/rspec'
require 'pact/consumer_contract'
require 'features/provider_states/zebras'


module Pact::Provider

  describe "A service production side of a pact" do

    class ServiceUnderTest

      def call(env)
        case env['PATH_INFO']
        when '/donuts'
          [201, {'Content-Type' => 'application/json'}, { message: "Donut created." }.to_json]
        when '/charlie'
          [200, {'Content-Type' => 'application/json'}, { message: "Your charlie has been deleted" }.to_json]
        end
      end

    end

    class ServiceUnderTestWithFixture

      def find_zebra_names
        #simulate loading data from a database
        data = JSON.load(File.read('tmp/a_mock_database.json'))
        data.collect{ | zebra | zebra['name'] }
      end

      def call(env)
        if (env['HTTP_AUTHORIZATION'])
          if env['HTTP_AUTHORIZATION'] != 'password'
            return [401, {'Content-Type' => 'application/json'}, {error: "The password is 'password'"}.to_json]
          end
        end
        case env['PATH_INFO']
        when "/zebra_names"
            [200, {'Content-Type' => 'application/json'}, { names: find_zebra_names }.to_json]
        end
      end

    end

    pact = Pact::ConsumerContract.from_json <<-EOS
    {
        "consumer" : { "name" : "a consumer"},
        "provider" : { "name" : "a provider"},
        "interactions" : [
            {
                "description": "donut creation request",
                "request": {
                    "method": "post",
                    "path": "/donuts"
                },
                "response": {
                    "body": {"message": "Donut created."},
                    "status": 201
                }
            },
            {
                "description": "charlie deletion request",
                "request": {
                    "method": "delete",
                    "path": "/charlie"
                },
                "response": {
                    "body": {
                      "message": {
                        "json_class": "Regexp",
                        "o": 0,
                        "s": "deleted"
                      }
                    },
                    "status": 200
                }
            }
        ]
    }
    EOS

    before :all do
        Pact.service_provider "My Provider" do
            app { ServiceUnderTest.new }
        end
    end

    honour_consumer_contract pact

  end

  describe "with a provider_state" do

    context "that is a symbol" do
        consumer_contract = Pact::ConsumerContract.from_json <<-EOS
        {
            "consumer" : { "name" : "the-wild-beast-store"},
            "provider" : { "name" : "provider"},
            "interactions" : [
                {
                    "description": "donut creation request",
                    "request": {
                        "method": "delete",
                        "path": "/zebra_names"
                    },
                    "response": {
                        "body": {"names": ["Jason", "Sarah"]},
                        "status": 200
                    },
                    "provider_state" : "the_zebras_are_here"
                }
            ]
        }
        EOS

        before :all do
            Pact.service_provider "My Provider" do
                app { ServiceUnderTestWithFixture.new }
            end
        end


        honour_consumer_contract consumer_contract
    end

    context "that is a string" do
        consumer_contract = Pact::ConsumerContract.from_json <<-EOS
        {
            "consumer" : { "name" : "some consumer"},
            "provider" : { "name" : "provider"},
            "interactions" : [
                {
                    "description": "donut creation request",
                    "request": {
                        "method": "post",
                        "path": "/zebra_names"
                    },
                    "response": {
                        "body": {"names": ["Mark", "Gertrude"]},
                        "status": 200
                    },
                    "provider_state" : "some other zebras are here"
                }
            ]
        }
        EOS

        before :all do
            Pact.service_provider "ServiceUnderTestWithFixture" do
                app { ServiceUnderTestWithFixture.new }
            end
        end


        honour_consumer_contract consumer_contract
    end

  end
end
