# frozen_string_literal: true

# Detects the media type of a URL based on its file extension.
#
# Single source of truth for media detection on the Ruby side. Extracted from
# TextSegmentationService#determine_media_type so it can be reused by
# MediaUrlExtractor (bot_runtime postback path) without duplicating the regex.
#
# IMPORTANT (regex drift): the bot_runtime (Go) has an equivalent detector in
# pkg/dispatch/service/dispatch_engine.go (extractMediaURLs). Both MUST stay in
# sync. The CRM keeps MediaUrlExtractor as a fallback, so a Go/Ruby divergence
# degrades gracefully (CRM re-detects from text) rather than losing media.
module AgentBots::MediaTypeDetector
  module_function

  IMAGE_EXT    = %w[jpg jpeg png gif bmp webp svg tiff].freeze
  AUDIO_EXT    = %w[mp3 wav ogg m4a aac flac].freeze
  VIDEO_EXT    = %w[mp4 avi mov wmv flv mkv webm].freeze
  DOCUMENT_EXT = %w[pdf doc docx xls xlsx ppt pptx txt rtf odt].freeze

  # Returns one of: 'image', 'audio', 'video', 'document', 'text'.
  # Matches the extension in the URL PATH, ignoring query string / fragment
  # (e.g. "https://x/v.mp4?token=1#t=10" => 'video').
  def detect(url)
    ext = extension(url)
    return 'text' if ext.blank?

    return 'image'    if IMAGE_EXT.include?(ext)
    return 'audio'    if AUDIO_EXT.include?(ext)
    return 'video'    if VIDEO_EXT.include?(ext)
    return 'document' if DOCUMENT_EXT.include?(ext)

    'text'
  end

  # Maps the detected media type to the Attachment#file_type enum value.
  # Note: Attachment has no :document — documents map to :file.
  def attachment_file_type(media_type)
    case media_type
    when 'image' then 'image'
    when 'audio' then 'audio'
    when 'video' then 'video'
    when 'document' then 'file'
    end
  end

  # Strip query/fragment, take the last path segment's extension, downcased.
  def extension(url)
    return nil if url.blank?

    path = url.to_s.split(/[?#]/, 2).first.to_s
    segment = path.split('/').last.to_s
    return nil unless segment.include?('.')

    segment.split('.').last.to_s.downcase
  end
end
