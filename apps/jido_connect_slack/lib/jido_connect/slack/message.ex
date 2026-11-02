defmodule Jido.Connect.Slack.Message do
  @moduledoc """
  A Slack message as `conversations.history` returns it, with its source.

  `channel` is the channel ID the page was requested for. `conversation_type`
  is the type the caller declared in the request, copied unchecked: Slack
  returns no type, and the package uses the declared one only to choose the
  history scope it checks before the call. It is not sent to Slack. A group
  DM declared as `public_channel` passes that check with `channels:history`;
  if the token also holds `mpim:history`, which Slack requires, the read
  succeeds and each message carries `conversation_type: "public_channel"`.
  Hosts must not base visibility, indexing or policy decisions on this field;
  the conversation's flags from `slack.conversation.info` or the host's own
  record say what it is.

  Timestamps stay Slack's exact strings. `user`, `bot_id` and `app_id`
  carry the author identity Slack supplies; none of them is derived. `text`
  is the full text: `""` when Slack sends an empty text, `nil` when it sends
  none. `blocks`, `attachments` and `files` keep Slack's nested maps as they
  arrive and are `nil` when absent. `edited` holds the editing user and the
  edit timestamp.

  A record with a missing `ts` or a value of the wrong type does not parse,
  so a malformed message fails instead of disappearing from a page.
  """

  @conversation_types ["public_channel", "private_channel", "im", "mpim"]

  @schema Zoi.struct(
            __MODULE__,
            %{
              channel: Zoi.string(),
              conversation_type: Zoi.enum(@conversation_types),
              ts: Zoi.string(),
              thread_ts: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              user: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              bot_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              app_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              text: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              blocks: Zoi.list(Zoi.map()) |> Zoi.nullish() |> Zoi.optional(),
              attachments: Zoi.list(Zoi.map()) |> Zoi.nullish() |> Zoi.optional(),
              files: Zoi.list(Zoi.map()) |> Zoi.nullish() |> Zoi.optional(),
              subtype: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              edited:
                Zoi.object(
                  %{
                    user: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
                    ts: Zoi.string()
                  },
                  coerce: true
                )
                |> Zoi.nullish()
                |> Zoi.optional()
            },
            coerce: true
          )

  @type t :: unquote(Zoi.type_spec(@schema))
  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)

  @doc "Slack conversation types a message can come from."
  @spec conversation_types() :: [String.t()]
  def conversation_types, do: @conversation_types

  def schema, do: @schema
  def new!(attrs), do: Zoi.parse!(@schema, attrs)
  def new(attrs), do: Zoi.parse(@schema, attrs)
end
