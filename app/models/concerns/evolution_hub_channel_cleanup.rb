# frozen_string_literal: true

# Deletes the paired Hub channel when a CRM Meta channel is destroyed.
#
# Without this, deleting an Inbox (which cascades `dependent: :destroy` to the
# Channel) only removes the local record — the Hub keeps the channel and its
# webhook, the next OAuth attempt collides with a stale token, and orphan
# rows accumulate in the Hub DB.
#
# Two storage shapes are supported because the channel types disagree:
#   - Channel::Whatsapp:    provider_config['evolution_hub']['channel_id']
#   - FacebookPage/Instagram: evolution_hub_meta['channel_id']
#
# Failures are logged but NOT raised — losing the Hub side is recoverable
# (admin can purge from the Hub UI), but blocking the CRM destroy would leave
# the operator unable to delete a broken inbox.
module EvolutionHubChannelCleanup
  extend ActiveSupport::Concern

  included do
    before_destroy :evolution_hub_cleanup
  end

  private

  def evolution_hub_cleanup
    hub_channel_id = extract_hub_channel_id
    return if hub_channel_id.blank?

    EvolutionHub::Client.new.delete_channel(hub_channel_id)
    Rails.logger.info("EvolutionHubChannelCleanup: deleted Hub channel #{hub_channel_id} for #{self.class.name}##{id}")
  rescue EvolutionHub::Client::RequestError => e
    Rails.logger.warn(
      "EvolutionHubChannelCleanup: Hub returned #{e.status} when deleting channel for #{self.class.name}##{id} — #{e.message}"
    )
  rescue EvolutionHub::Client::ConfigurationError => e
    Rails.logger.warn("EvolutionHubChannelCleanup: skipped — Hub not configured (#{e.message})")
  rescue StandardError => e
    Rails.logger.error("EvolutionHubChannelCleanup: unexpected error for #{self.class.name}##{id} — #{e.class}: #{e.message}")
  end

  def extract_hub_channel_id
    if respond_to?(:provider_config) && provider_config.is_a?(Hash)
      return provider_config.dig('evolution_hub', 'channel_id')
    end

    if respond_to?(:evolution_hub_meta) && evolution_hub_meta.is_a?(Hash)
      return evolution_hub_meta['channel_id']
    end

    nil
  end
end
