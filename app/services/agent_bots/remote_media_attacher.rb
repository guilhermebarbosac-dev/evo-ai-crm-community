# frozen_string_literal: true

require 'down'
require 'resolv'
require 'ipaddr'

# Downloads remote media URLs and BUILDS attachments on a Message *before* it is
# saved, so they commit atomically with the message.
#
# WHY build (not create!): Message#send_reply (app/models/message.rb) runs on
# after_create_commit and does:
#   attachments.blank? ? SendReplyJob.perform_later(id)
#                      : SendReplyJob.set(wait: 5.seconds).perform_later(id)
# If the message commits WITHOUT attachments, the channel dispatch fires
# immediately with text only, and attaching media afterwards does NOT re-send
# (only triggers a re-render via after_update_commit). So attachments MUST exist
# at the moment of the message commit. This mirrors the incoming pattern in
# whatsapp/incoming_message_base_service.rb (attachments.new before save).
#
# Caller contract: pass an UNSAVED message; this builds attachments in memory;
# the caller then saves the message once (message.save! / create!).
class AgentBots::RemoteMediaAttacher
  MAX_SIZE       = 50.megabytes
  OPEN_TIMEOUT   = 5  # seconds — keep short so we don't blow the bot_runtime's 30s postback timeout
  READ_TIMEOUT   = 15 # seconds
  VALID_FILE_TYPES = %w[image audio video file].freeze

  # message: unsaved Message; media: [{ url:, file_type: }]
  # Builds attachments on the message (does NOT save). Returns the message.
  def self.build_attachments(message, media)
    new(message, media).build_attachments
  end

  def initialize(message, media)
    @message = message
    @media = Array(media)
  end

  def build_attachments
    @media.each do |item|
      url = item[:url] || item['url']
      file_type = (item[:file_type] || item['file_type']).to_s

      next unless valid_file_type?(file_type, url)
      next unless safe_url?(url)

      build_one(url, file_type)
    end

    @message
  end

  private

  def valid_file_type?(file_type, url)
    return true if VALID_FILE_TYPES.include?(file_type)

    Rails.logger.warn "[RemoteMediaAttacher] Skipping invalid file_type=#{file_type.inspect} for #{url}"
    false
  end

  def build_one(url, file_type)
    downloaded = Down.download(
      url,
      max_size: MAX_SIZE,
      open_timeout: OPEN_TIMEOUT,
      read_timeout: READ_TIMEOUT,
      # SSRF: the safe_url? check only validated the initial host. Down follows
      # redirects by default, so a 302 -> internal address would bypass it.
      # Disallow redirects entirely; agent media URLs should be direct links.
      max_redirects: 0
    )

    @message.attachments.new(
      file_type: file_type,
      file: {
        io: downloaded,
        filename: filename_for(url, downloaded),
        content_type: downloaded.content_type
      }
    )
    Rails.logger.info "[RemoteMediaAttacher] Built #{file_type} attachment from #{url}"
  rescue Down::Error, StandardError => e
    # A failed download must not drop the message or the other media (AC11).
    Rails.logger.error "[RemoteMediaAttacher] Failed to download #{url}: #{e.class} #{e.message}"
  end

  def filename_for(url, downloaded)
    name = downloaded.original_filename.presence
    name ||= File.basename(URI.parse(url).path.presence || 'media')
    name.presence || 'media'
  rescue URI::InvalidURIError
    'media'
  end

  # SSRF guard: the URL comes from LLM output (untrusted). Reject anything that
  # resolves to a private / loopback / link-local / reserved address, including
  # the cloud metadata endpoint (169.254.169.254).
  def safe_url?(url)
    uri = URI.parse(url)
    return reject(url, 'non-http(s) scheme') unless %w[http https].include?(uri.scheme)
    return reject(url, 'missing host') if uri.host.blank?

    addresses(uri.host).each do |addr|
      ip = IPAddr.new(addr)
      if ip.loopback? || ip.private? || ip.link_local? ||
         reserved?(ip)
        return reject(url, "blocked address #{addr}")
      end
    end
    true
  rescue URI::InvalidURIError, IPAddr::InvalidAddressError, Resolv::ResolvError, SocketError => e
    reject(url, "#{e.class}: #{e.message}")
  end

  def addresses(host)
    # If host is already an IP, use it; otherwise resolve A/AAAA.
    IPAddr.new(host)
    [host]
  rescue IPAddr::InvalidAddressError
    Resolv.getaddresses(host)
  end

  # Catch metadata / broadcast / unspecified ranges not covered by #private?.
  def reserved?(ip)
    %w[
      169.254.0.0/16 0.0.0.0/8 100.64.0.0/10
      ::1/128 fc00::/7 fe80::/10
    ].any? { |range| IPAddr.new(range).include?(ip) }
  end

  def reject(url, reason)
    Rails.logger.warn "[RemoteMediaAttacher] SSRF guard rejected #{url}: #{reason}"
    false
  end
end
