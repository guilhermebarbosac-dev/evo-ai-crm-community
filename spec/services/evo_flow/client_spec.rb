require 'rails_helper'
require 'webmock/rspec'

RSpec.describe EvoFlow::Client do
  let(:api_url) { 'http://evo-flow:3000/api/v1' }
  let(:api_key) { 'xyz' }
  let(:client) { described_class.new(api_url: api_url, api_key: api_key, timeout: 5) }
  let(:track_url) { "#{api_url}/events/track" }
  let(:payload) { { event: 'contact.created', contactId: '42' } }

  describe '#post' do
    it 'POSTs to the full /api/v1 URL with auth + json headers (AC1)' do
      stub = stub_request(:post, track_url)
             .with(
               body: payload.to_json,
               headers: {
                 'X-Integration-API-Key' => api_key,
                 'Content-Type' => 'application/json'
               }
             )
             .to_return(
               status: 200,
               body: { messageId: 'm-1', status: 'queued' }.to_json,
               headers: { 'Content-Type' => 'application/json' }
             )

      result = client.post('/events/track', payload)

      expect(stub).to have_been_requested
      expect(result).to include('messageId' => 'm-1', 'status' => 'queued')
    end

    it 'keeps the /api/v1 prefix and never hits the bare root (F8)' do
      good = stub_request(:post, track_url).to_return(status: 200, body: '{}')
      root = stub_request(:post, 'http://evo-flow:3000/events/track')

      client.post('/events/track', payload)
      client.post('events/track', payload)       # no leading slash
      client.post('//events/track', payload)     # doubled leading slash

      expect(good).to have_been_requested.times(3)
      expect(root).not_to have_been_requested
    end

    it 'raises EvoFlow::HTTPError with #code and #response on HTTP 500 (AC2)' do
      stub_request(:post, track_url).to_return(status: 500, body: 'boom')

      expect { client.post('/events/track', payload) }
        .to raise_error(EvoFlow::HTTPError) { |error|
          expect(error.code).to eq(500)
          expect(error.response).to be_present
          expect(error.response.body).to eq('boom')
        }
    end

    it 'raises EvoFlow::HTTPError with nil code on a refused connection (AC2b)' do
      stub_request(:post, track_url).to_raise(Errno::ECONNREFUSED)

      expect { client.post('/events/track', payload) }
        .to raise_error(EvoFlow::HTTPError) { |error|
          expect(error.code).to be_nil
          expect(error.message).to include('evo-flow request failed')
        }
    end

    it 'raises EvoFlow::HTTPError with nil code on a timeout (AC2b)' do
      stub_request(:post, track_url).to_timeout

      expect { client.post('/events/track', payload) }
        .to raise_error(EvoFlow::HTTPError) { |error| expect(error.code).to be_nil }
    end

    it 'raises EvoFlow::HTTPError on an unparseable 2xx body (F2)' do
      stub_request(:post, track_url)
        .to_return(status: 200, body: '{not-json', headers: { 'Content-Type' => 'application/json' })

      expect { client.post('/events/track', payload) }
        .to raise_error(EvoFlow::HTTPError) { |error|
          expect(error.code).to eq(200)
          expect(error.message).to include('unparseable')
        }
    end

    it 'never logs an auth-rejection body (may echo the key) (F3)' do
      stub_request(:post, track_url).to_return(status: 401, body: 'token=xyz leaked')
      logged = []
      allow(Rails.logger).to receive(:error) { |m| logged << m }

      expect { client.post('/events/track', payload) }.to raise_error(EvoFlow::HTTPError) { |error|
        expect(error.message).to include('[redacted: auth failure]')
        expect(error.message).not_to include('xyz leaked')
      }
      expect(logged.join).to include('[redacted: auth failure]')
      expect(logged.join).not_to include('xyz leaked')
    end
  end

  describe 'configuration safety' do
    it 'raises ConfigurationError when the API key is blank (F13)' do
      expect { described_class.new(api_url: api_url, api_key: '') }
        .to raise_error(EvoFlow::ConfigurationError, /not set/)
      expect { described_class.new(api_url: api_url, api_key: nil) }
        .to raise_error(EvoFlow::ConfigurationError)
    end

    context 'when in production' do
      before { allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production')) }

      it 'refuses cleartext http without an explicit opt-out (F1)' do
        expect { described_class.new(api_url: 'http://evo-flow:3000/api/v1', api_key: 'k') }
          .to raise_error(EvoFlow::ConfigurationError, /cleartext/)
      end

      it 'allows https' do
        expect { described_class.new(api_url: 'https://evo-flow/api/v1', api_key: 'k') }
          .not_to raise_error
      end

      it 'allows http only with the explicit insecure opt-out' do
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:fetch).with('EVO_FLOW_ALLOW_INSECURE', nil).and_return('true')
        expect { described_class.new(api_url: 'http://evo-flow:3000/api/v1', api_key: 'k') }
          .not_to raise_error
      end
    end
  end

  describe 'ENV defaults (F9 — consistent ENV.fetch)' do
    it 'falls back to the documented default base URL' do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch)
        .with('EVO_FLOW_API_URL', described_class::DEFAULT_API_URL)
        .and_return(described_class::DEFAULT_API_URL)
      allow(ENV).to receive(:fetch).with('AUTH_APIKEY_INTEGRATION_LOCAL', nil).and_return('k')

      stub = stub_request(:post, 'http://evo-flow:3000/api/v1/events/track')
             .to_return(status: 200, body: '{}')

      described_class.new.post('/events/track', payload)

      expect(stub).to have_been_requested
    end
  end
end
