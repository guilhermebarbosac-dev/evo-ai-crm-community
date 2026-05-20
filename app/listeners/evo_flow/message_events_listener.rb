# frozen_string_literal: true

module EvoFlow
  # Subscribes to Wisper :message_created and forwards to evo-flow as a
  # track event. See EvoFlow::ContactEventsListener for the canonical
  # listener template.
  #
  # `evo_flow_enabled?` is duplicated across the 4 EvoFlow listeners by
  # design (tech-spec §Technical Decisions #2: no shared base class).
  #
  # Hot-path note (F4): this handler fires per inbound message. The
  # `message.conversation.inbox` access can incur 2 extra SQL reads if the
  # caller hasn't preloaded the association. Bulk paths SHOULD preload
  # `conversation: :inbox`; the listener does not preload defensively.
  class MessageEventsListener
    TRACK_PATH = '/events/track'

    def message_created(data)
      return if data.respond_to?(:data)

      event_data = data[:data] || data
      message = event_data[:message]
      return log_missing_message unless message
      return unless evo_flow_enabled?

      inbox = inbox_for(message)
      return warn_inbox_missing(message) unless inbox

      enqueue_track(message, inbox)
    rescue StandardError => e
      log_failure(__method__, e)
    end

    private

    def inbox_for(message)
      message.conversation&.inbox
    end

    def log_missing_message
      Rails.logger.error('EvoFlow::MessageEventsListener#message_created: message is nil')
      nil
    end

    def warn_inbox_missing(message)
      Rails.logger.warn(
        "EvoFlow::MessageEventsListener#message_created: inbox missing for message #{message.id}"
      )
      nil
    end

    def enqueue_track(message, inbox)
      event_name = 'message.created'
      source_event_uuid = "#{message.id}.#{message.created_at.to_i}"
      contact_id = message.conversation.contact_id
      message_id = EvoFlow::PayloadBuilder.message_id_for(event_name, contact_id, source_event_uuid)
      payload = EvoFlow::PayloadBuilder.build_track(
        event_name: event_name,
        contact_id: contact_id,
        properties: build_properties(message, inbox),
        occurred_at: message.created_at,
        message_id: message_id
      )
      # Sidekiq strict_args!(:raise) rejects symbol keys and non-JSON values;
      # PayloadBuilder is out of scope for this story — normalise at boundary.
      EvoFlow::PublishEventWorker.perform_async(TRACK_PATH, JSON.parse(payload.to_json))
    end

    # Raw content is intentionally passed through; EvoFlow::PublishEventWorker
    # redacts `properties` only when persisting Sidekiq args / failure
    # broadcasts, not in-flight to evo-flow which needs the content.
    def build_properties(message, inbox)
      {
        message_id: message.id,
        conversation_id: message.conversation_id,
        message_type: message.message_type,
        content_type: message.content_type,
        content: message.content,
        channel_type: inbox.channel_type,
        source: 'messaging'
      }
    end

    def evo_flow_enabled?
      ENV['AUTH_APIKEY_INTEGRATION_LOCAL'].present?
    end

    # F6/F8 mitigation: see ContactEventsListener#log_failure for rationale.
    def log_failure(handler, error)
      tag = enqueue_loss?(error) ? '[EvoFlow][enqueue-loss]' : '[EvoFlow]'
      Rails.logger.error(
        "#{tag} EvoFlow::MessageEventsListener##{handler} failed: #{error.class}: #{error.message}"
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
