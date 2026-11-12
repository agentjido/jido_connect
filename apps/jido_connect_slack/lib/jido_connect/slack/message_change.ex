defmodule Jido.Connect.Slack.MessageChange do
  @moduledoc """
  An edit or a deletion of a Slack message, from an Events API `message`
  event with the subtype `message_changed` or `message_deleted`.

  `subtype` says which one it is. `ts` is the source key: the `ts` of the
  message that was edited or deleted, taken from `message.ts` of an edit or
  a tombstone and from `deleted_ts` of a deletion. With `channel` it names
  the original message, as `slack.conversation.history` and the message
  triggers do.
  `notification_ts` is the `ts` of the change event itself and `event_ts`
  Slack's `event_ts`; Slack gives each notification a new one, so neither
  names the message. `event_id` differs for every notification, also for
  two edits of the same message.

  An edit carries the message as it is after the edit: `text`, the author
  as `user`, `bot_id` and `app_id`, `thread_ts` for a thread reply, and the
  editor and edit time from `message.edited` as `editor` and `edited_ts`.
  `text` is Slack's full text as Slack stores it. It stays `""` when Slack
  stores an empty text, as after an edit to an empty text beside an
  attachment; for an empty text beside blocks, Slack stores the blocks'
  text.

  A deletion carries no text. Its `user`, `bot_id`, `app_id` and
  `thread_ts` come from `previous_message` when Slack sends it, and are
  `nil` without it. Slack does not say who deleted a message.

  Slack reports the deletion of a thread parent that has replies as a
  `message_changed` event whose `message` is a tombstone, with the subtype
  `tombstone` and Slackbot as `user`. It becomes a deletion with the
  `message_deleted` subtype: `ts` and `thread_ts` come from the tombstone,
  the author from `previous_message`. When the last reply is deleted, Slack
  removes the tombstone with a `message_deleted` event whose
  `previous_message` is the tombstone; that second deletion of the same
  `ts` names no author.

  `view` says whose view the notification comes from: `"bot"` when Slack
  names the bot's installation in the delivery's `authorizations`, `"user"`
  when it names the user token of a person who authorized the app.
  `viewer` is that authorization's user ID, the bot user or the person.
  Both are `nil` when the delivery names no authorization.

  IDs and timestamps stay Slack's exact strings. `team_id`, `event_id`,
  `channel` and `ts` must be non-empty strings; every other field is a
  string or `nil`.
  """

  @subtypes ["message_changed", "message_deleted"]
  @channel_types ["channel", "group", "im", "mpim"]
  @views Jido.Connect.Slack.Webhook.View.views()

  # `coerce: true` lets a plain map become the struct; field types stay
  # strict, so a number never turns into a string.
  @schema Zoi.struct(
            __MODULE__,
            %{
              team_id: Zoi.string(min_length: 1),
              event_id: Zoi.string(min_length: 1),
              channel: Zoi.string(min_length: 1),
              channel_type: Zoi.enum(@channel_types) |> Zoi.nullish() |> Zoi.optional(),
              subtype: Zoi.enum(@subtypes),
              ts: Zoi.string(min_length: 1),
              thread_ts: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              user: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              bot_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              app_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              editor: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              edited_ts: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              text: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              notification_ts: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              event_ts: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              view: Zoi.enum(@views) |> Zoi.nullish() |> Zoi.optional(),
              viewer: Zoi.string() |> Zoi.nullish() |> Zoi.optional()
            },
            coerce: true
          )

  @type t :: unquote(Zoi.type_spec(@schema))
  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)

  @doc "Slack message subtypes that describe a change."
  @spec subtypes() :: [String.t()]
  def subtypes, do: @subtypes

  def schema, do: @schema
  def new(attrs), do: Zoi.parse(@schema, attrs)
end
