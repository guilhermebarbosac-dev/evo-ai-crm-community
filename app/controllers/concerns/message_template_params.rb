# frozen_string_literal: true

# Strong params for message template create/update, shared between the dedicated
# Api::V1::MessageTemplatesController (global + channel-bound CRUD) and any other
# consumer. Extracted from InboxesController during the EVO-1716 cutover so the
# permitted shape lives in one place. (EVO-1716)
module MessageTemplateParams
  extend ActiveSupport::Concern

  private

  def extract_message_template_params # rubocop:disable Metrics/MethodLength
    params.require(:message_template).permit(
      :name,
      :content,
      :language,
      :category,
      :template_type,
      :media_url,
      :media_type,
      :active,
      components: [
        :type,
        :format,
        :text,
        :url,
        {
          buttons: [:type, :text, :url, :phone_number]
        }
      ],
      variables: [:name, :label, :type, :required, :default_value, :source, :example, :position, :component],
      settings: {},
      metadata: {}
    )
  end
end
