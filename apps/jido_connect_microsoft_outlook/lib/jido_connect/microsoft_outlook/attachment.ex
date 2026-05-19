defmodule Jido.Connect.MicrosoftOutlook.Attachment do
  @moduledoc """
  Normalized Outlook Mail attachment metadata.

  Maps from Microsoft Graph `attachment` / `fileAttachment` resources.
  Stores only metadata fields — no inline base64 content bytes.
  """

  @schema Zoi.struct(
            __MODULE__,
            %{
              attachment_id: Zoi.string(),
              name: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              content_type: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              size: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
              is_inline: Zoi.boolean() |> Zoi.default(false),
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
