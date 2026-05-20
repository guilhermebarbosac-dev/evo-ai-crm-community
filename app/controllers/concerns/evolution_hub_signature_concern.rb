# frozen_string_literal: true

# Validates the X-Hub-Signature-256 header on inbound webhooks posted by the
# Evolution Hub. The Hub signs the raw request body with HMAC-SHA256 using
# the shared EVOLUTION_HUB_WEBHOOK_SECRET (configured per-installation in
# the SuperAdmin panel) and sends it as "sha256=<hex>".
#
# Mirrors Meta's own webhook signature scheme so it feels familiar.
module EvolutionHubSignatureConcern
  extend ActiveSupport::Concern

  HEADER = 'X-Hub-Signature-256'

  private

  def verify_evolution_hub_signature!
    secret = GlobalConfigService.load('EVOLUTION_HUB_WEBHOOK_SECRET', nil).to_s
    if secret.blank?
      Rails.logger.warn('EvolutionHub webhook: refused — EVOLUTION_HUB_WEBHOOK_SECRET is not configured')
      head :unauthorized
      return
    end

    provided = request.headers[HEADER].to_s
    unless provided.start_with?('sha256=')
      Rails.logger.warn('EvolutionHub webhook: refused — missing or malformed signature header')
      head :unauthorized
      return
    end

    expected = "sha256=#{OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha256'), secret, request.raw_post)}"
    unless ActiveSupport::SecurityUtils.secure_compare(expected, provided)
      Rails.logger.warn('EvolutionHub webhook: refused — signature mismatch')
      head :unauthorized
      return
    end

    true
  end
end
