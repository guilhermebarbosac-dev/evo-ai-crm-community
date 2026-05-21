# TODO: lets use HTTParty instead of RestClient
#
# Legacy telemetry client (kept for installation/onboarding). The active
# Evolution Hub *proxy* integration uses the EvolutionHub::* module namespace
# (lib/evolution_hub/{client,inbox_builder}.rb + app/services/evolution_hub/).
class EvolutionHubTelemetry
  BASE_URL = ENV.fetch('EVOLUTION_HUB_URL', 'https://localhost:9999')
  PING_URL = "#{BASE_URL}/ping".freeze
  REGISTRATION_URL = "#{BASE_URL}/instances".freeze
  PUSH_NOTIFICATION_URL = "#{BASE_URL}/send_push".freeze
  EVENTS_URL = "#{BASE_URL}/events".freeze
  BILLING_URL = "#{BASE_URL}/billing".freeze

  def self.installation_identifier
    identifier = InstallationConfig.find_by(name: 'INSTALLATION_IDENTIFIER')&.value
    identifier ||= InstallationConfig.create!(name: 'INSTALLATION_IDENTIFIER', value: SecureRandom.uuid).value
    identifier
  end

  def self.billing_url
    "#{BILLING_URL}?installation_identifier=#{installation_identifier}"
  end

  def self.pricing_plan
    InstallationConfig.find_by(name: 'INSTALLATION_PRICING_PLAN')&.value || 'community'
  end

  def self.pricing_plan_quantity
    InstallationConfig.find_by(name: 'INSTALLATION_PRICING_PLAN_QUANTITY')&.value || 0
  end

  def self.support_config
    {
      support_website_token: InstallationConfig.find_by(name: 'EVOLUTION_SUPPORT_WEBSITE_TOKEN')&.value,
      support_script_url: InstallationConfig.find_by(name: 'EVOLUTION_SUPPORT_SCRIPT_URL')&.value,
      support_identifier_hash: InstallationConfig.find_by(name: 'EVOLUTION_SUPPORT_IDENTIFIER_HASH')&.value
    }
  end

  def self.instance_config
    {
      installation_identifier: installation_identifier,
      installation_version: Evolution.config[:version],
      installation_host: URI.parse(ENV.fetch('FRONTEND_URL', '')).host,
      installation_env: ENV.fetch('INSTALLATION_ENV', ''),
      edition: ENV.fetch('EVOLUTION_EDITION', '')
    }
  end

  def self.instance_metrics
    {
      users_count: fetch_count(User),
      inboxes_count: fetch_count(Inbox),
      conversations_count: fetch_count(Conversation),
      incoming_messages_count: fetch_count(Message.incoming),
      outgoing_messages_count: fetch_count(Message.outgoing),
      additional_information: {}
    }
  end

  def self.fetch_count(model)
    model.last&.id || 0
  end

  def self.sync_with_hub
    # TELEMETRY DISABLED BY DEFAULT: Always return local version without external communication
    return { 'version' => Evolution.config[:version] }
  end

  def self.register_instance(_company_name, _owner_name, _owner_email)
    # TELEMETRY DISABLED BY DEFAULT: No instance registration
    Rails.logger.info 'Instance registration blocked for privacy'
    return
  end

  def self.send_push(_fcm_options)
    # TELEMETRY DISABLED BY DEFAULT: No push notifications
    Rails.logger.info 'Push notification blocked for privacy'
    return
  end

  def self.emit_event(_event_name, _event_data)
    # TELEMETRY DISABLED BY DEFAULT: No event emission
    return
  end
end
