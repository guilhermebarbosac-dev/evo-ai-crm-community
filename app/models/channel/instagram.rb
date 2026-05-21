# == Schema Information
#
# Table name: channel_instagram
#
#  id                 :uuid             not null, primary key
#  access_token       :string           not null
#  evolution_hub_meta :jsonb            not null
#  expires_at         :datetime         not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  instagram_id       :string           not null
#
# Indexes
#
#  index_channel_instagram_on_instagram_id  (instagram_id) UNIQUE
#
class Channel::Instagram < ApplicationRecord
  include Channelable
  include Reauthorizable
  include ChannelMessageTemplates
  include EvolutionHubChannelCleanup
  self.table_name = 'channel_instagram'

  AUTHORIZATION_ERROR_THRESHOLD = 1

  validates :access_token, presence: true
  validates :instagram_id, uniqueness: true, presence: true

  after_create_commit :subscribe
  after_update_commit :resubscribe_if_token_changed
  before_destroy :unsubscribe

  def name
    'Instagram'
  end

  def create_contact_inbox(instagram_id, name)
    @contact_inbox = ::ContactInboxWithContactBuilder.new({
                                                            source_id: instagram_id,
                                                            inbox: inbox,
                                                            contact_attributes: { name: name }
                                                          }).perform
  end

  def subscribe
    # ref https://developers.facebook.com/docs/instagram-platform/webhooks#enable-subscriptions
    Rails.logger.info("Instagram: Subscribing to webhooks for instagram_id=#{instagram_id}")

    response = HTTParty.post(
      "https://graph.instagram.com/v23.0/#{instagram_id}/subscribed_apps",
      query: {
        subscribed_fields: %w[messages message_reactions messaging_seen message_edit comments live_comments],
        access_token: access_token
      }
    )

    if response.success?
      Rails.logger.info("Instagram: Webhook subscription SUCCESS for instagram_id=#{instagram_id}")
    else
      Rails.logger.error("Instagram: Webhook subscription FAILED for instagram_id=#{instagram_id} - Status: #{response.code}, Body: #{response.body}")
    end

    true
  rescue StandardError => e
    Rails.logger.error("Instagram: Webhook subscription ERROR for instagram_id=#{instagram_id} - #{e.class}: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    true
  end

  def unsubscribe
    HTTParty.delete(
      "https://graph.instagram.com/v23.0/#{instagram_id}/subscribed_apps",
      query: {
        access_token: access_token
      }
    )
    true
  rescue StandardError => e
    Rails.logger.debug { "Rescued: #{e.inspect}" }
    true
  end

  def access_token
    Instagram::RefreshOauthTokenService.new(channel: self).access_token
  end

  # Check subscription status
  def subscription_status
    Rails.logger.info("Instagram: Checking subscription status for instagram_id=#{instagram_id}")

    response = HTTParty.get(
      "https://graph.instagram.com/v23.0/#{instagram_id}/subscribed_apps",
      query: {
        access_token: access_token
      }
    )

    if response.success?
      data = response.parsed_response
      Rails.logger.info("Instagram: Subscription status for instagram_id=#{instagram_id}: #{data.inspect}")
      data
    else
      Rails.logger.error("Instagram: Failed to check subscription status for instagram_id=#{instagram_id} - Status: #{response.code}, Body: #{response.body}")
      nil
    end
  rescue StandardError => e
    Rails.logger.error("Instagram: Error checking subscription status for instagram_id=#{instagram_id} - #{e.class}: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    nil
  end

  private

  # Re-subscribe if access_token was updated (e.g., after reauthorization)
  def resubscribe_if_token_changed
    return unless saved_change_to_access_token?

    Rails.logger.info("Instagram: Access token changed, re-subscribing to webhooks for instagram_id=#{instagram_id}")
    subscribe
  end
end
