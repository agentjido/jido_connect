defmodule Jido.Connect.MicrosoftOutlook.Message do
  @moduledoc """
  Normalized Outlook Mail message metadata.

  Maps from Microsoft Graph `message` resources to a stable,
  provider-agnostic struct. Stores headers, recipients, and body
  previews only — no raw body content or MIME data.
  """

  @schema Zoi.struct(
            __MODULE__,
            %{
              message_id: Zoi.string(),
              conversation_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              subject: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              body_preview: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              body_summary: Zoi.map() |> Zoi.default(%{}),
              sender: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              from: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              to_recipients: Zoi.list(Zoi.map()) |> Zoi.default([]),
              cc_recipients: Zoi.list(Zoi.map()) |> Zoi.default([]),
              bcc_recipients: Zoi.list(Zoi.map()) |> Zoi.default([]),
              internet_message_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              received_date_time: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              sent_date_time: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              importance: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              is_read: Zoi.boolean() |> Zoi.nullish() |> Zoi.optional(),
              is_draft: Zoi.boolean() |> Zoi.nullish() |> Zoi.optional(),
              has_attachments: Zoi.boolean() |> Zoi.nullish() |> Zoi.optional(),
              folders: Zoi.list(Zoi.string()) |> Zoi.default([]),
              attachments: Zoi.list(Zoi.map()) |> Zoi.default([]),
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
