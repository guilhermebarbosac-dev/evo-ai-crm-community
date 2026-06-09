# frozen_string_literal: true

# Splits an agent reply into plain text and the media URLs it contains.
#
# Used by the bot_runtime postback path (Webhooks::BotRuntimeController) as a
# FALLBACK when the bot_runtime does not send structured attachments in the
# payload. Media URLs (by extension) are pulled out of the text and returned as
# structured media; non-media URLs stay in the text untouched.
#
# Returns: { text: <text without media urls>, media: [{ url:, file_type: }] }
# where file_type is the Attachment enum value ('image'/'audio'/'video'/'file').
class AgentBots::MediaUrlExtractor
  # Matches http(s) URLs. Stops at whitespace; trailing punctuation is trimmed
  # below so a URL at the end of a sentence ("...VLS.mp4.") parses cleanly.
  URL_REGEX = %r{https?://[^\s<>"']+}i

  def self.call(content)
    new(content).call
  end

  def initialize(content)
    @content = content.to_s
  end

  def call
    media = []
    residual = @content.dup

    @content.scan(URL_REGEX).each do |raw_url|
      url = trim_trailing_punctuation(raw_url)
      media_type = AgentBots::MediaTypeDetector.detect(url)
      next if media_type == 'text' # non-media URL stays in the text

      file_type = AgentBots::MediaTypeDetector.attachment_file_type(media_type)
      next if file_type.blank?

      media << { url: url, file_type: file_type }
      # Remove only this media URL from the residual text (the matched span).
      residual = residual.sub(raw_url, '')
    end

    { text: residual.strip, media: media }
  end

  private

  # URLs at end of a sentence often capture a trailing ) . , ! ? — strip them.
  def trim_trailing_punctuation(url)
    url.sub(/[)\].,!?;:]+\z/, '')
  end
end
