# frozen_string_literal: true

module EvolutionHub
  # Orchestrates creation of an Inbox when the Evolution Hub feature is on.
  #
  # Flow:
  #   1. Create the local Channel record in `pending` state (no Meta tokens
  #      yet — the operator hasn't authorised the Hub link).
  #   2. Call the Hub's single-shot endpoint to create a paired channel +
  #      webhook in one request, passing the local Channel UUID as
  #      external_id so the Hub can echo it back on lifecycle webhooks.
  #   3. Persist the Hub channel_id / channel_token / public_link on the
  #      local Channel so the UI can deep-link to the connect flow.
  #   4. Create the Inbox tied to the Channel.
  #   5. Return { inbox:, public_link: } so the controller can hand the link
  #      to the frontend, which opens it in a new tab.
  class InboxBuilder
    SUPPORTED_TYPES = {
      'whatsapp_cloud'   => :build_whatsapp,
      'facebook_page'    => :build_facebook,
      'facebook'         => :build_facebook,
      'instagram'        => :build_instagram
    }.freeze

    class UnsupportedChannelType < StandardError; end

    def initialize(account:, channel_type:, name:)
      @account = account
      @channel_type = channel_type.to_s
      @name = name.to_s.presence || "#{@channel_type.humanize} via Evolution Hub"
    end

    def perform
      handler = SUPPORTED_TYPES[@channel_type]
      raise UnsupportedChannelType, "channel_type=#{@channel_type} cannot use Evolution Hub" unless handler

      ActiveRecord::Base.transaction do
        channel = send(handler)
        hub_response = create_in_hub(channel)
        persist_hub_metadata(channel, hub_response)
        inbox = create_inbox(channel)
        { inbox: inbox, public_link: extract_public_link(hub_response) }
      end
    end

    private

    def hub_client
      @hub_client ||= EvolutionHub::Client.new
    end

    def crm_webhook_url
      # Built off the configured CRM URL. We must include the route prefix
      # the routes file uses (api/v2/accounts/:id/webhooks/evolution_hub).
      account_id = @account.id
      base = ENV.fetch('FRONTEND_URL') { Rails.application.routes.default_url_options[:host] || 'http://localhost:3000' }
      "#{base.chomp('/')}/webhooks/accounts/#{account_id}/evolution_hub"
    end

    def webhook_secret
      GlobalConfigService.load('EVOLUTION_HUB_WEBHOOK_SECRET', nil)
    end

    def hub_channel_type(channel)
      case channel
      when Channel::Whatsapp     then 'whatsapp'
      when Channel::FacebookPage then 'facebook'
      when Channel::Instagram    then 'instagram'
      end
    end

    def build_whatsapp
      Channel::Whatsapp.create!(
        account: @account,
        phone_number: pending_phone_placeholder,
        provider: 'whatsapp_cloud',
        provider_config: {
          'api_key' => '',
          'phone_number_id' => '',
          'business_account_id' => '',
          'evolution_hub' => { 'status' => 'pending' }
        }
      )
    end

    def build_facebook
      Channel::FacebookPage.create!(
        account: @account,
        user_access_token: '',
        page_access_token: '',
        page_id: "pending_#{SecureRandom.hex(6)}",
        evolution_hub_meta: { 'status' => 'pending' }
      )
    end

    def build_instagram
      Channel::Instagram.create!(
        account: @account,
        access_token: '',
        instagram_id: "pending_#{SecureRandom.hex(6)}",
        expires_at: 60.days.from_now,
        evolution_hub_meta: { 'status' => 'pending' }
      )
    end

    def pending_phone_placeholder
      "+0000#{SecureRandom.random_number(10**10)}"
    end

    def create_in_hub(channel)
      hub_client.create_channel(
        type: hub_channel_type(channel),
        name: @name,
        external_id: channel.id.to_s,
        webhook_url: crm_webhook_url,
        webhook_secret: webhook_secret,
        webhook_events: %w[channel_connected channel_disconnected event_received webhook_delivered webhook_failed]
      )
    end

    def persist_hub_metadata(channel, hub_response)
      channel_body = hub_response.is_a?(Hash) ? (hub_response['channel'] || {}) : {}
      hub_block = {
        'channel_id'    => channel_body['id'],
        'channel_token' => channel_body['token'],
        'public_link'   => build_public_link(channel_body['token']),
        'status'        => 'pending'
      }

      if channel.is_a?(Channel::Whatsapp)
        provider_config = (channel.provider_config || {}).deep_dup
        provider_config['evolution_hub'] = hub_block
        channel.update!(provider_config: provider_config)
      else
        channel.update!(evolution_hub_meta: (channel.evolution_hub_meta || {}).merge(hub_block))
      end
    end

    def build_public_link(channel_token)
      return nil if channel_token.blank?
      hub_frontend = ENV.fetch('EVOLUTION_HUB_FRONTEND_URL') do
        MetaBaseUrl.hub_url.sub(/(\Ahttps?:\/\/)api\./, '\1app.')
      end
      "#{hub_frontend.chomp('/')}/connect/#{channel_token}"
    end

    def extract_public_link(hub_response)
      channel_body = hub_response.is_a?(Hash) ? (hub_response['channel'] || {}) : {}
      build_public_link(channel_body['token'])
    end

    def create_inbox(channel)
      Inbox.create!(
        account: @account,
        channel: channel,
        name: @name
      )
    end
  end
end
