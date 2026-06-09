# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AgentBots::MediaUrlExtractor do
  describe '.call' do
    it 'splits trailing media URL from text' do
      result = described_class.call('Assiste aí https://x.com/uploads/VLS_Atleta.mp4')
      expect(result[:text]).to eq('Assiste aí')
      expect(result[:media]).to eq([{ url: 'https://x.com/uploads/VLS_Atleta.mp4', file_type: 'video' }])
    end

    it 'handles media-only content (residual empty)' do
      result = described_class.call('https://x.com/pic.jpg')
      expect(result[:text]).to eq('')
      expect(result[:media]).to eq([{ url: 'https://x.com/pic.jpg', file_type: 'image' }])
    end

    it 'keeps non-media URLs in the text' do
      result = described_class.call('veja em https://site.com/pagina')
      expect(result[:text]).to eq('veja em https://site.com/pagina')
      expect(result[:media]).to be_empty
    end

    it 'maps document URLs to file_type file' do
      result = described_class.call('o manual https://x.com/manual.pdf')
      expect(result[:media]).to eq([{ url: 'https://x.com/manual.pdf', file_type: 'file' }])
    end

    it 'trims trailing punctuation from URLs' do
      result = described_class.call('olha (https://x.com/v.mp4).')
      expect(result[:media].first[:url]).to eq('https://x.com/v.mp4')
    end

    it 'extracts multiple media URLs preserving order' do
      result = described_class.call('foto https://x.com/a.jpg e video https://x.com/b.mp4')
      expect(result[:media]).to eq([
                                     { url: 'https://x.com/a.jpg', file_type: 'image' },
                                     { url: 'https://x.com/b.mp4', file_type: 'video' }
                                   ])
    end

    it 'returns empty media and original text when no URLs' do
      result = described_class.call('texto puro sem links')
      expect(result[:text]).to eq('texto puro sem links')
      expect(result[:media]).to be_empty
    end
  end
end
