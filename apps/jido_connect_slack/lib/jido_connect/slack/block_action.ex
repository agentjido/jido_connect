defmodule Jido.Connect.Slack.BlockAction do
  @moduledoc """
  A click on a Block Kit button in a Slack message, from an interactivity
  `block_actions` payload.

  `user_id` is the person who clicked. It comes from `user.id`, not from
  the message's `user`, and is the message's author or the app's installer
  only when that person clicked; the host decides who may click.
  `channel_id` and `message_ts` name the message that holds the button,
  and `thread_ts` its thread when Slack sends one. `action_id`, `block_id`
  and `value` are the button's identifiers and opaque value as the poster
  set them, and `action_ts` is Slack's time of the click.

  IDs, timestamps and the value stay Slack's exact strings. Slack allows a
  button `value` of up to 2,000 characters and an `action_id` or `block_id`
  of up to 255; a longer one does not parse.
  """

  @schema Zoi.struct(
            __MODULE__,
            %{
              api_app_id: Zoi.string(min_length: 1),
              team_id: Zoi.string(min_length: 1),
              enterprise_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              user_id: Zoi.string(min_length: 1),
              user_team_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              channel_id: Zoi.string(min_length: 1),
              message_ts: Zoi.string(min_length: 1),
              thread_ts: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              action_id: Zoi.string(min_length: 1, max_length: 255),
              block_id: Zoi.string(min_length: 1, max_length: 255),
              value: Zoi.string(min_length: 1, max_length: 2_000),
              action_ts: Zoi.string(min_length: 1)
            },
            coerce: true
          )

  @type t :: unquote(Zoi.type_spec(@schema))
  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)

  def schema, do: @schema
  def new(attrs), do: Zoi.parse(@schema, attrs)
end
