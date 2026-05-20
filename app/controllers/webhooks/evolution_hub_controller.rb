# frozen_string_literal: true

# Receives webhooks posted by the Evolution Hub. Two payload shapes arrive
# here:
#
#   1. Hub lifecycle events (channel_connected / channel_disconnected /
#      channel_auto_imported / webhook_delivered / event_received) carrying
#      the Hub's canonical JSON shape with "event_type" at the top level.
#
#   2. Forwarded Meta webhooks, with the EXACT payload Meta itself posts
#      (object: "whatsapp_business_account" | "page" | "instagram", entry: [...]).
#      The Hub forwards these raw so the CRM can dispatch into the existing
#      Webhooks::{Whatsapp,Facebook,Instagram} processing pipeline without
#      any payload translation.
#
# Both flavours land in the same async job. The controller does the bare
# minimum: HMAC validation, capture of X-Hub-Delivery-Id, enqueue, 200 OK.
module Webhooks
  class EvolutionHubController < ApplicationController
    include EvolutionHubSignatureConcern

    skip_before_action :verify_authenticity_token

    def create
      return unless verify_evolution_hub_signature!

      delivery_id = request.headers['X-Hub-Delivery-Id'].presence || SecureRandom.uuid
      raw_body = request.raw_post

      Webhooks::EvolutionHubEventsJob.perform_later(raw_body, delivery_id)

      head :ok
    end
  end
end
