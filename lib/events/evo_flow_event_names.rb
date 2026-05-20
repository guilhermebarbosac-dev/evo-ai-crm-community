module EvoFlow
  # Canonical list of event names CRM emits to evo-flow.
  # Dot-notation matches the Events::Types convention (lib/events/types.rb).
  EVENT_NAMES = %w[
    contact.created contact.updated contact.deleted
    contact.label.added contact.label.removed contact.custom_attribute.changed
    conversation.created conversation.resolved
    message.created message.delivered message.read message.failed
    campaign.triggered campaign.message.sent campaign.message.opened campaign.message.clicked
  ].freeze
end
