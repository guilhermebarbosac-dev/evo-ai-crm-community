# frozen_string_literal: true

# Marks the local Channel as inactive when the Hub reports the underlying
# Meta connection went away (admin removed the channel at the Hub, token
# revoked at Meta, etc).
module EvolutionHub
  class ChannelDisconnectedHandler
    def initialize(payload)
      @payload = payload
    end

    def perform
      external_id = @payload['external_id'].to_s
      return if external_id.blank?

      [Channel::Whatsapp, Channel::FacebookPage, Channel::Instagram].each do |klass|
        record = klass.find_by(id: external_id)
        next unless record

        if record.is_a?(Channel::Whatsapp)
          provider_config = (record.provider_config || {}).deep_dup
          hub_block = provider_config['evolution_hub'] || {}
          hub_block['status'] = 'inactive'
          provider_config['evolution_hub'] = hub_block
          record.update!(provider_config: provider_config)
        else
          hub_meta = (record.evolution_hub_meta || {}).merge('status' => 'inactive')
          record.update!(evolution_hub_meta: hub_meta)
        end

        Rails.logger.info("EvolutionHub::ChannelDisconnected: #{klass.name}##{record.id} marked inactive")
        break
      end
    end
  end
end
