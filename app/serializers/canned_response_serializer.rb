# frozen_string_literal: true

module CannedResponseSerializer
  extend self

  def serialize(canned_response)
    {
      id: canned_response.id,
      short_code: canned_response.short_code,
      content: canned_response.content,
      created_at: canned_response.created_at&.iso8601,
      updated_at: canned_response.updated_at&.iso8601,
      attachments: serialize_attachments(canned_response.attachments)
    }
  end

  def serialize_collection(canned_responses)
    return [] unless canned_responses
    canned_responses.map { |response| serialize(response) }
  end

  def serialize_attachments(attachments)
    return [] unless attachments
    attachments.map do |att|
      blob = att.file.blob
      next unless blob
      base_url = "https://api-crm.agenciabasex.com"
      file_path = "/rails/active_storage/blobs/redirect/#{blob.signed_id}/#{blob.filename}"
      {
        id: att.id,
        file_type: att.file_type,
        file_size: blob.byte_size,
        fallback_title: blob.filename.to_s,
        content_type: blob.content_type,
        data_url: base_url + file_path,
        file_url: base_url + file_path,
        thumb_url: base_url + file_path
      }
    end.compact
  end
end
