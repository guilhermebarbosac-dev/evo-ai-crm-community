class ZapiSyncListener < BaseListener
  def inbox_created(event)
    inbox = event.data[:inbox]

    Rails.logger.info "Z-API: ZapiSyncListener inbox_created called for inbox #{inbox.id} (#{inbox.name}) with display_name: #{inbox.display_name}"

    return unless zapi_channel?(inbox)
    Rails.logger.info "Z-API: Inbox is Z-API channel on creation"

    # On creation, sync the display_name with Z-API instance name
    if inbox.display_name.present?
      Rails.logger.info "Z-API: display_name present on creation, syncing with Z-API"
      sync_inbox_name_with_zapi(inbox)
    else
      Rails.logger.info "Z-API: display_name not present on creation, skipping sync"
    end
  end

  def inbox_updated(event)
    inbox = event.data[:inbox]
    changed_attributes = extract_changed_attributes(event)

    Rails.logger.info "Z-API: ZapiSyncListener inbox_updated called for inbox #{inbox.id} (#{inbox.name}) with display_name: #{inbox.display_name}"

    return unless zapi_channel?(inbox)
    Rails.logger.info "Z-API: Inbox is Z-API channel"

    Rails.logger.info "Z-API: Changed attributes: #{changed_attributes.inspect}"

    # Always sync display_name when inbox is updated and display_name is present
    # This ensures synchronization even if changed_attributes is empty (which can happen
    # if the event doesn't capture changes properly or if the update happens in a transaction)
    if inbox.display_name.present?
      Rails.logger.info "Z-API: display_name present (#{inbox.display_name}), syncing with Z-API"
      sync_inbox_name_with_zapi(inbox)
    else
      Rails.logger.info "Z-API: display_name not present, skipping sync"
    end
  end

  private

  def zapi_channel?(inbox)
    is_whatsapp = inbox.channel_type == 'Channel::Whatsapp'

    # `provider` só existe em Channel::Whatsapp. Para outros canais (Telegram,
    # etc.) `inbox.channel.provider` levanta NoMethodError e derruba o
    # EventDispatcherJob inteiro — por isso só lemos provider quando o canal
    # for WhatsApp.
    return false unless is_whatsapp

    provider = inbox.channel&.provider
    is_zapi = provider == 'zapi'

    Rails.logger.info "Z-API: Checking if channel is Z-API - channel_type: #{inbox.channel_type}, provider: #{provider}, is_whatsapp: #{is_whatsapp}, is_zapi: #{is_zapi}"

    is_zapi
  end

  def sync_inbox_name_with_zapi(inbox)
    whatsapp_channel = inbox.channel
    provider_config = whatsapp_channel.provider_config || {}

    instance_id = provider_config['instance_id']
    token = provider_config['token']
    client_token = provider_config['client_token']

    return unless instance_id.present? && token.present? && client_token.present?

    # Update instance name in Z-API
    update_zapi_instance_name(instance_id, token, client_token, inbox.display_name)
  rescue StandardError => e
    Rails.logger.error "Z-API: Error syncing inbox name with Z-API: #{e.message}"
  end

  def update_zapi_instance_name(instance_id, token, client_token, name)
    api_url = 'https://api.z-api.io'
    url = "#{api_url}/instances/#{instance_id}/token/#{token}/update-name"

    uri = URI.parse(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == 'https')
    http.open_timeout = 15
    http.read_timeout = 15

    request = Net::HTTP::Put.new(uri)
    request['Content-Type'] = 'application/json'
    request['Client-Token'] = client_token if client_token.present?
    request.body = { value: name }.to_json

    response = http.request(request)

    unless response.is_a?(Net::HTTPSuccess)
      Rails.logger.error "Z-API: Failed to update instance name. Status: #{response.code}, Body: #{response.body}"
      raise "Failed to update instance name: #{response.code}"
    end

    Rails.logger.info "Z-API: Successfully updated instance name to '#{name}' for instance #{instance_id}"
  rescue StandardError => e
    Rails.logger.error "Z-API: Error updating instance name: #{e.message}"
    raise e
  end
end
