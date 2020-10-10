describe Pact::Provider::PactURI do
  let(:uri) { 'http://uri' }
  let(:username) { 'pact' }
  let(:options) { { username: username } }
  let(:pact_uri) { Pact::Provider::PactURI.new(uri, options) }

  describe '#==' do
    it 'should return false if object is not PactURI' do
      expect(pact_uri == Object.new).to be false
    end

    it 'should return false if uri is not equal' do
      expect(pact_uri == Pact::Provider::PactURI.new('other_uri', options)).to be false
    end

    it 'should return false if uri options are not equal' do
      expect(pact_uri == Pact::Provider::PactURI.new(uri, username: 'wrong user')).to be false
    end

    it 'should return true if uri and options are equal' do
      expect(pact_uri == Pact::Provider::PactURI.new(uri, options)).to be true
    end
  end

  describe '#to_s' do
    context 'with basic auth provided' do
      let(:password) { 'my_password' }
      let(:options) { { username: username, password: password } }

      it 'should include user name and and hide password' do
        expect(pact_uri.to_s).to eq('http://pact:*****@uri')
      end

      context 'when basic auth credentials have been set for a local file (eg. via environment variables, unintentionally)' do
        let(:uri) { '/some/file thing.json' }

        it 'does not blow up' do
          expect(pact_uri.to_s).to eq uri
        end
      end
    end

    context 'with personal access token provided' do
      let(:pat) { 'should_be_secret' }
      let(:options) { { username: pat } }

      it 'should hide the pat' do
        expect(pact_uri.to_s).to eq('http://*****@uri')
      end

      context 'when pat credentials have been set for a local file (eg. via environment variables, unintentionally)' do
        let(:uri) { '/some/file thing.json' }

        it 'does not blow up' do
          expect(pact_uri.to_s).to eq uri
        end
      end
    end

    context 'without userinfo' do
      let(:options) { {} }

      it 'should return original uri string' do
        expect(pact_uri.to_s).to eq(uri)
      end
    end
  end
end