defmodule Jido.Connect.MicrosoftCalendar.Privacy do
  @moduledoc """
  Microsoft Calendar privacy boundary helpers.

  Calendar event subjects, body previews, attendee addresses, and location
  metadata can contain personal or schedule data. Full event body content,
  attendee responses, and private appointment details are intentionally
  excluded from normalized metadata structs in future normalizer work.
  """

  @calendar_content_fields [
    :subject,
    :body_preview,
    :body_summary,
    :organizer,
    :attendees,
    :location,
    :start,
    :end,
    :i_cal_uid
  ]

  @personal_data_fields [
    :display_name,
    :address,
    :owner,
    :calendar_id,
    :email,
    :subject,
    :body_preview,
    :organizer,
    :attendees,
    :location
  ]

  @raw_body_keys MapSet.new([
                   "content",
                   :content
                 ])

  @doc "Fields that should be treated as calendar content."
  def calendar_content_fields, do: @calendar_content_fields

  @doc "Fields that should be treated as personal data."
  def personal_data_fields, do: @personal_data_fields

  @doc "Returns true for raw body or content keys that should not survive default normalization."
  def raw_body_key?(key), do: MapSet.member?(@raw_body_keys, key)
end
