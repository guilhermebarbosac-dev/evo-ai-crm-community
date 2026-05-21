# == Schema Information
#
# Table name: channel_facebook_pages
#
#  id                 :uuid             not null, primary key
#  evolution_hub_meta :jsonb            not null
#  page_access_token  :string           not null
#  user_access_token  :string           not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  instagram_id       :string
#  page_id            :string           not null
#
# Indexes
#
#  index_channel_facebook_pages_on_page_id  (page_id) UNIQUE
#

class Channel::FacebookPage < ApplicationRecord
  include Channelable
  include Reauthorizable
  include ChannelMessageTemplates
  include EvolutionHubChannelCleanup

  self.table_name = 'channel_facebook_pages'

  validates :page_id, uniqueness: true

  after_create_commit :subscribe
  before_destroy :unsubscribe

  def name
    'Facebook'
  end

  def create_contact_inbox(instagram_id, name)
    @contact_inbox = ::ContactInboxWithContactBuilder.new({
                                                            source_id: instagram_id,
                                                            inbox: inbox,
                                                            contact_attributes: { name: name }
                                                          }).perform
  end

  def subscribe
    # ref https://developers.facebook.com/docs/messenger-platform/reference/webhook-events
    fields = %w[messages message_deliveries message_echoes message_reads standby messaging_handovers feed]

    Rails.logger.info("Facebook page #{page_id}: Subscribing to fields: #{fields.join(', ')}")

    Facebook::Messenger::Subscriptions.subscribe(
      access_token: page_access_token,
      subscribed_fields: fields
    )
  rescue StandardError => e
    Rails.logger.error("Facebook page #{page_id}: Subscription error: #{e.inspect}")
    Rails.logger.debug { "Rescued: #{e.inspect}" }
    true
  end

  # Public method to re-subscribe webhook
  def resubscribe_webhook
    subscribe
  end

  private

  def unsubscribe
    Facebook::Messenger::Subscriptions.unsubscribe(access_token: page_access_token)
  rescue StandardError => e
    Rails.logger.debug { "Rescued: #{e.inspect}" }
    true
  end
end
