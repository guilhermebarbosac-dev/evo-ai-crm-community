module EvoFlow
  # Shapes the real evo-flow DTOs (camelCase, single-tenant: NO accountId).
  # track  -> TrackEventDto    (uses `event`)
  # identify -> IdentifyEventDto (uses `eventName`)
  # See evo-flow/src/modules/events/dto/*.
  class PayloadBuilder
    # Exactly 5 kwargs (RuboCop ParameterLists max 5 — do not add a 6th).
    def self.build_track(event_name:, contact_id:, properties:, occurred_at:, message_id:)
      {
        messageId: message_id,
        contactId: contact_id.to_s,
        event: event_name,
        properties: properties || {},
        timestamp: iso8601(occurred_at)
      }
    end

    def self.build_identify(event_name:, contact_id:, traits:, occurred_at:, message_id:)
      {
        messageId: message_id,
        contactId: contact_id.to_s,
        eventName: event_name,
        traits: traits || {},
        timestamp: iso8601(occurred_at)
      }
    end

    # Deterministic, forward-looking idempotency key. NOTE: evo-flow has no
    # consumer-side dedup yet (clickhouse contact_events is MergeTree); Sidekiq
    # retries currently still duplicate downstream. Tracked separately.
    def self.message_id_for(event_name, contact_id, source_event_uuid)
      Digest::SHA256.hexdigest("#{event_name}|#{contact_id}|#{source_event_uuid}")
    end

    # Always emits UTC ISO-8601. A String is validated by re-parsing (fail
    # fast with ArgumentError rather than shipping an unparseable timestamp
    # that evo-flow would silently misread/reject downstream).
    def self.iso8601(time)
      return Time.iso8601(time).utc.iso8601 if time.is_a?(String)

      (time || Time.current).utc.iso8601
    end
  end
end
