require 'rails_helper'

RSpec.describe EvoFlow::PublishEventWorker, type: :job do
  let(:client) { instance_double(EvoFlow::Client) }
  let(:path) { '/events/track' }
  let(:payload) do
    { 'messageId' => 'm-1', 'contactId' => '42', 'event' => 'contact.created',
      'properties' => { 'email' => 'pii@example.com' } }
  end

  before { allow(EvoFlow::Client).to receive(:new).and_return(client) }

  describe '#perform' do
    it 'forwards path + payload to EvoFlow::Client#post (happy path)' do
      allow(client).to receive(:post).and_return('messageId' => 'm-1', 'status' => 'queued')

      described_class.new.perform(path, payload)

      expect(client).to have_received(:post).with(path, payload)
    end

    it 're-raises EvoFlow::HTTPError so Sidekiq counts the retry' do
      allow(client).to receive(:post).and_raise(EvoFlow::HTTPError.new('500', 500, nil))

      expect { described_class.new.perform(path, payload) }
        .to raise_error(EvoFlow::HTTPError)
    end

    it 're-raises non-HTTPError too so every failure path counts as a retry (F4)' do
      allow(client).to receive(:post).and_raise(ArgumentError, 'bad args')

      expect { described_class.new.perform(path, payload) }
        .to raise_error(ArgumentError)
    end
  end

  describe '.sanitize_payload (F3)' do
    it 'redacts PII-bearing fields, keeps identifiers, tolerates symbol keys' do
      expect(described_class.sanitize_payload(payload)).to eq(
        'messageId' => 'm-1', 'contactId' => '42', 'event' => 'contact.created',
        'properties' => '[redacted]'
      )
      expect(described_class.sanitize_payload(traits: { email: 'x' }, contactId: '7'))
        .to eq(traits: '[redacted]', contactId: '7')
    end

    it 'passes non-hash payloads through untouched' do
      expect(described_class.sanitize_payload('raw')).to eq('raw')
    end
  end

  describe 'sidekiq configuration' do
    it 'uses the integrations queue and retry: 5 (overrides global 3)' do
      expect(described_class.sidekiq_options['queue']).to eq(:integrations)
      expect(described_class.sidekiq_options['retry']).to eq(5)
    end
  end

  describe 'retries exhausted -> Wisper :evo_flow_publish_failed (AC4)' do
    let(:listener) do
      Class.new do
        attr_reader :received

        def evo_flow_publish_failed(args)
          @received = args
        end
      end.new
    end

    it 'broadcasts with path + error and a PII-redacted payload (AC4 + F3)' do
      job = { 'args' => [path, payload], 'class' => described_class.name }
      exception = EvoFlow::HTTPError.new('boom', 500, nil)

      Wisper.subscribe(listener) do
        described_class.sidekiq_retries_exhausted_block.call(job, exception)
      end

      expect(listener.received).to be_present
      expect(listener.received[:data][:path]).to eq(path)
      expect(listener.received[:data][:error]).to eq('boom')
      expect(listener.received[:data][:payload]['properties']).to eq('[redacted]')
      expect(listener.received[:data][:payload]['messageId']).to eq('m-1')
    end
  end
end
