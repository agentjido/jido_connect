defmodule Jido.Connect.MicrosoftCalendar.Event do
  @moduledoc """
  Normalized Microsoft Calendar event metadata.

  Maps from Microsoft Graph `event` resources to a stable,
  provider-agnostic struct. Stores subject, time window, attendees,
  location, recurrence, and organizer metadata. Full body content is
  intentionally excluded from normalized metadata to prevent content
  leakage — only a body summary is retained.
  """

  @schema Zoi.struct(
            __MODULE__,
            %{
              event_id: Zoi.string(),
              i_cal_uid: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              subject: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              body_preview: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              body_summary: Zoi.map() |> Zoi.default(%{}),
              start: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              end: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              organizer: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              attendees: Zoi.list(Zoi.map()) |> Zoi.default([]),
              location: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              locations: Zoi.list(Zoi.map()) |> Zoi.default([]),
              recurrence: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              is_all_day: Zoi.boolean() |> Zoi.nullish() |> Zoi.optional(),
              is_cancelled: Zoi.boolean() |> Zoi.nullish() |> Zoi.optional(),
              is_organizer: Zoi.boolean() |> Zoi.nullish() |> Zoi.optional(),
              sensitivity: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              show_as: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              series_master_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              transaction_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              online_meeting_url: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              online_meeting: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              response_status: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              has_attachments: Zoi.boolean() |> Zoi.nullish() |> Zoi.optional(),
              calendar_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              metadata: Zoi.map() |> Zoi.default(%{})
            },
            coerce: true
          )

  @type t :: unquote(Zoi.type_spec(@schema))
  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)

  def schema, do: @schema
  def new!(attrs), do: Zoi.parse!(@schema, attrs)
  def new(attrs), do: Zoi.parse(@schema, attrs)
end
