# frozen_string_literal: true

require 'rails_helper'

# EVO-1255 / EVO-1716: evo-flow journey nodes list a channel's templates
# server-side with the service token. After the EVO-1716 cutover this is served
# by the flat endpoint with an `inbox_id` filter (the inbox-nested GET route was
# removed). The MessageTemplatePolicy must honor service authentication instead
# of dereferencing a nil user.
RSpec.describe 'Api::V1::MessageTemplates (service token)', type: :request do
  let(:service_token) { 'spec-service-token' }
  let(:headers) { { 'X-Service-Token' => service_token } }
  let(:channel) { Channel::Api.create!(hmac_mandatory: false) }
  let(:inbox) { Inbox.create!(channel: channel, name: "Inbox #{SecureRandom.hex(3)}") }

  before { ENV['EVOAI_CRM_API_TOKEN'] = service_token }

  after do
    ENV.delete('EVOAI_CRM_API_TOKEN')
    Current.reset
  end

  it 'lists a channel templates by inbox_id with a valid service token' do
    template = MessageTemplate.create!(
      name: "ch-#{SecureRandom.hex(4)}",
      content: 'Olá {{first_name}}',
      channel: channel
    )

    get "/api/v1/message_templates?inbox_id=#{inbox.id}&active=true&per_page=-1",
        headers: headers, as: :json

    expect(response).to have_http_status(:ok)
    names = response.parsed_body['data'].map { |t| t['name'] }
    expect(names).to include(template.name)
  end

  it 'rejects the call without a service token or user' do
    get '/api/v1/message_templates', as: :json

    expect(response).to have_http_status(:unauthorized)
  end
end
