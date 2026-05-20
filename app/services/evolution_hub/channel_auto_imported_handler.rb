# frozen_string_literal: true

# Records that the Hub auto-imported a Meta channel that previously existed
# outside it. We don't have a local Channel to mutate (the CRM didn't create
# this one as a Hub channel), so we just log it for now. Once the operator
# decides to "Migrate" the channel to Hub-managed status, the upcoming
# migration flow will look up by phone_number_id/page_id and stash the
# returned channel_id / channel_token.
module EvolutionHub
  class ChannelAutoImportedHandler
    def initialize(payload)
      @payload = payload
    end

    def perform
      Rails.logger.info(
        "EvolutionHub::ChannelAutoImported: channel_id=#{@payload['channel_id']} " \
        "external_id=#{@payload['external_id'].inspect} " \
        "channel_type=#{@payload['channel_type'].inspect}"
      )
      # Future: pre-populate provider_config['evolution_hub'] by matching on
      # phone_number_id / page_id / instagram_user_id.
    end
  end
end
