defmodule Jido.Connect.MicrosoftOutlook.Privacy do
  @moduledoc """
  Outlook Mail privacy boundary helpers.

  Outlook Mail message subjects, body previews, recipient addresses, and
  attachment metadata can contain personal or message content. Full body HTML
  or text content, inline base64 attachment bytes, and raw MIME data are
  intentionally excluded from normalized metadata structs. The Normalizer
  summarizes body content to content-type and byte-size only.
  """

  @message_content_fields [
    :subject,
    :body_preview,
    :body_summary,
    :sender,
    :from,
    :to_recipients,
    :cc_recipients,
    :bcc_recipients,
    :internet_message_id
  ]

  @personal_data_fields [
    :display_name,
    :address,
    :well_known_name,
    :user_id,
    :email,
    :user_principal_name
  ]

  @raw_body_keys MapSet.new([
                   "content",
                   "contentBytes",
                   :content,
                   :contentBytes
                 ])

  @doc "Fields that should be treated as message content."
  def message_content_fields, do: @message_content_fields

  @doc "Fields that should be treated as personal data."
  def personal_data_fields, do: @personal_data_fields

  @doc "Returns true for raw body or content keys that should not survive default normalization."
  def raw_body_key?(key), do: MapSet.member?(@raw_body_keys, key)
end
