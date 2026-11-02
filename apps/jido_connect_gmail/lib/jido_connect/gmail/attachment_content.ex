defmodule Jido.Connect.Gmail.AttachmentContent do
  @moduledoc """
  One attachment of a Gmail message with its bytes, returned by
  `google.gmail.message.attachment.content.get`.

    * `message_id`, `thread_id` and `history_id` are Gmail's fields of the
      message that holds the attachment.
    * `part_id` is Gmail's `partId`, the only identity of the part. The
      attachment manifest of `google.gmail.message.content.get` lists the
      part IDs to choose from: its entries and its enclosed messages.
    * `attachment_id` is Gmail's `body.attachmentId` when Gmail keeps the
      data behind one, and `nil` for data that Gmail returned inline. Gmail
      issues a new attachment ID with every response.
    * `filename`, `mime_type`, `size`, `disposition` and `content_id` are the
      fields of the manifest entry. `size` is Gmail's `body.size`, the number
      of original bytes.
    * `data` holds the bytes as the base64url string that Gmail returned,
      padded or not. It decodes to exactly `size` bytes. Inline `text/*`
      data that Gmail may have converted to UTF-8 is not returned; the
      action fails with reason `:attachment_converted`, and the attachment
      lookup section of `Jido.Connect.Gmail.MIME.Traversal` lists the cases.

  The connector does not interpret the bytes. For an enclosed message they
  are the whole original, its headers and body included.
  """

  @schema Zoi.struct(
            __MODULE__,
            %{
              message_id: Zoi.string(),
              thread_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              history_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              part_id: Zoi.string(),
              attachment_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              filename: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              mime_type: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              size: Zoi.integer(),
              disposition: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              content_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              data: Zoi.string(),
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
