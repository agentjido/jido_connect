defmodule Jido.Connect.Gmail.MessageContent do
  @moduledoc """
  Complete content of a Gmail message.

  `google.gmail.message.content.get` returns one, and
  `google.gmail.thread.content.get` returns one per message of the thread.
  Unlike `Jido.Connect.Gmail.Message`, this struct carries body text.

    * `message_id`, `thread_id`, `history_id`, `label_ids` and
      `internal_date` are Gmail's message fields. `internal_date` is Gmail's
      `internalDate`, milliseconds since the Unix epoch, as a string.
    * `headers` lists every header of the message in Gmail's order as
      `%{name: name, value: value}` maps, repeated headers included.
    * `from`, `to`, `cc`, `bcc`, `reply_to`, `subject`, `date`,
      `rfc_message_id`, `in_reply_to` and `references` hold the value of the
      first header of that name (`Reply-To`, `Message-ID`, `In-Reply-To`),
      matched without regard to case, or `nil`. Values stay as Gmail returns
      them; addresses are neither parsed nor verified.
    * `text_parts` lists every body `text/plain` and `text/html` part in
      Gmail's part order, also those that Gmail stores behind an
      `attachmentId`, which the action fetches with `attachments.get`.
    * `attachments` is the attachment manifest. The action fetches no
      attachment bytes; `google.gmail.message.attachment.get` returns them
      for an `attachment_id` from the manifest.
    * `messages` lists the enclosed `message/rfc822` messages for which Gmail
      supplies nested parts: the manifest fields of the part, its `headers`
      and its own `text_parts`, `attachments` and `messages`. A
      `message/rfc822` part without nested parts is a manifest entry.

  Text parts and manifest entries have the shapes that
  `Jido.Connect.Gmail.MIME.Traversal` documents. Text is never truncated. An
  inline forward keeps the quoted original inside its text parts: the struct
  neither separates a comment from a quoted original nor verifies a quoted or
  enclosed sender.
  """

  @schema Zoi.struct(
            __MODULE__,
            %{
              message_id: Zoi.string(),
              thread_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              history_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              label_ids: Zoi.list(Zoi.string()) |> Zoi.default([]),
              internal_date: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              headers: Zoi.list(Zoi.map()) |> Zoi.default([]),
              from: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              to: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              cc: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              bcc: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              reply_to: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              subject: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              date: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              rfc_message_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              in_reply_to: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              references: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              text_parts: Zoi.list(Zoi.map()) |> Zoi.default([]),
              attachments: Zoi.list(Zoi.map()) |> Zoi.default([]),
              messages: Zoi.list(Zoi.map()) |> Zoi.default([]),
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
