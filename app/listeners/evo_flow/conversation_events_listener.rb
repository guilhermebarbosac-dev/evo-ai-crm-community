# frozen_string_literal: true

module EvoFlow
  # Subscribes to Wisper :conversation_created and forwards to evo-flow as
  # a track event. See EvoFlow::ContactEventsListener for the canonical
  # listener template.
  #
  # `evo_flow_enabled?` is duplicated across the 4 EvoFlow listeners by
  # design (tech-spec §Technical Decisions #2: no shared base class).
  class ConversationEventsListener
    TRACK_PATH = '/events/track'

    def conversation_created(data)
      return if data.respond_to?(:data)

      event_data = data[:data] || data
      conversation = event_data[:conversation]
      unless conversation
        Rails.logger.error('EvoFlow::ConversationEventsListener#conversation_created: conversation is nil')
        return
      end
      return unless evo_flow_enabled?

      enqueue_track(conversation)
    rescue StandardError => e
      log_failure(__method__, e)
    end

    private

    def enqueue_track(conversation)
      event_name = 'conversation.created'
      source_event_uuid = "#{conversation.id}.#{conversation.created_at.to_i}"
      contact_id = conversation.contact_id
      message_id = EvoFlow::PayloadBuilder.message_id_for(event_name, contact_id, source_event_uuid)
      payload = EvoFlow::PayloadBuilder.build_track(
        event_name: event_name,
        contact_id: contact_id,
        properties: build_properties(conversation),
        occurred_at: conversation.created_at,
        message_id: message_id
      )
      # Sidekiq strict_args!(:raise) rejects symbol keys and non-JSON values;
      # PayloadBuilder is out of scope for this story — normalise at boundary.
      EvoFlow::PublishEventWorker.perform_async(TRACK_PATH, JSON.parse(payload.to_json))
    end

    def build_properties(conversation)
      inbox = conversation.inbox
      {
        conversation_id: conversation.id,
        inbox_id: conversation.inbox_id,
        inbox_name: inbox&.name,
        channel_type: inbox&.channel_type,
        source: 'conversation_management'
      }
    end

    def evo_flow_enabled?
      ENV['AUTH_APIKEY_INTEGRATION_LOCAL'].present?
    end

    # F6/F8 mitigation: see ContactEventsListener#log_failure for rationale.
    def log_failure(handler, error)
      tag = enqueue_loss?(error) ? '[EvoFlow][enqueue-loss]' : '[EvoFlow]'
      Rails.logger.error(
        "#{tag} EvoFlow::ConversationEventsListener##{handler} failed: #{error.class}: #{error.message}"
      )
      Sentry.capture_exception(error) if defined?(Sentry)
      nil
    end

    def enqueue_loss?(error)
      return true if defined?(Redis::BaseConnectionError) && error.is_a?(Redis::BaseConnectionError)

      error.is_a?(ArgumentError) && error.message.include?('occurred_at is required')
    end
  end
end
