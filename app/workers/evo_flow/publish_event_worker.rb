module EvoFlow
  # Pure Sidekiq worker (repo convention: include Sidekiq::Worker, lives in
  # app/workers/). retry: 5 overrides the global sidekiq.yml max_retries: 3.
  #
  # On retry exhaustion the sidekiq_retries_exhausted hook fires and the job
  # lands in the (default-on) Dead Set, broadcasting Wisper
  # :evo_flow_publish_failed for downstream handling (listener wired later).
  # Honest caveat: this hook runs in-process on the final attempt; if that
  # process is hard-killed (OOM/SIGKILL) the hook does not run — terminal
  # alerting then relies on Dead Set monitoring, not this broadcast.
  #
  # Signature is perform(path, payload) — Client#post needs the target path;
  # documented divergence from EVO-1238's perform(payload).
  class PublishEventWorker
    include Sidekiq::Worker
    sidekiq_options queue: :integrations, retry: 5

    # Event content may carry PII (contact traits/properties). It is redacted
    # before being persisted as Sidekiq job args / Dead Set / Wisper payload;
    # only identifiers needed for triage and replay decisions are kept.
    PII_KEYS = %w[properties traits].freeze

    # Wisper 2.0.0 exposes NO `Wisper.publish`; global listeners registered via
    # `Wisper.subscribe` (config/initializers/contact_company_listeners.rb) are
    # notified by any Wisper::Publisher#broadcast. `publish` is private, so
    # wrap it. Mirrors the repo idiom in Contacts::BulkTransferService.
    class FailureBroadcaster
      include Wisper::Publisher

      def broadcast_failed(path:, payload:, error:)
        publish('evo_flow_publish_failed', data: { path: path, payload: payload, error: error })
      end
    end

    def self.sanitize_payload(payload)
      return payload unless payload.is_a?(Hash)

      payload.each_with_object({}) do |(key, value), acc|
        acc[key] = PII_KEYS.include?(key.to_s) ? '[redacted]' : value
      end
    end

    sidekiq_retries_exhausted do |job, ex|
      args = job['args'] || []
      path = args[0]
      safe_payload = EvoFlow::PublishEventWorker.sanitize_payload(args[1])
      Rails.logger.error("[EvoFlow] terminal failure path=#{path} msg=#{ex.message}")
      FailureBroadcaster.new.broadcast_failed(path: path, payload: safe_payload, error: ex.message)
    end

    def perform(path, payload)
      EvoFlow::Client.new.post(path, payload)
      Rails.logger.info("[EvoFlow] published path=#{path} messageId=#{message_id(payload)}")
    rescue EvoFlow::HTTPError => e
      Rails.logger.warn(
        "[EvoFlow] publish failed (will retry) path=#{path} code=#{e.code} msg=#{e.message}"
      )
      raise
    rescue StandardError => e
      # Any other failure (unparseable body, bad args, config error) must also
      # count as a Sidekiq retry and reach the exhaustion path uniformly.
      Rails.logger.warn("[EvoFlow] publish errored (will retry) path=#{path} msg=#{e.message}")
      raise
    end

    private

    # Sidekiq JSON-serialises args → string keys for enqueued jobs; tolerate
    # symbol keys too (in-process / console invocation with builder output).
    def message_id(payload)
      return unless payload.is_a?(Hash)

      payload['messageId'] || payload[:messageId]
    end
  end
end
