defmodule Jido.Connect.Slack.Webhook.MessageChanges do
  @moduledoc false

  # Turns a `message` event with the subtype `message_changed` or
  # `message_deleted` into a change signal: the fields of
  # `Jido.Connect.Slack.MessageChange` that are not nil. The signal's `ts` is
  # the edited or deleted message's `ts`, never the notification's.
  #
  # Slack reports the deletion of a thread parent with replies as a
  # `message_changed` whose `message` is a tombstone, and the removal of the
  # tombstone after the last reply as a `message_deleted` whose
  # `previous_message` is the tombstone. Both are deletions; a tombstone
  # names Slackbot as author, so neither takes its author from one.
  #
  # Every value is read at a fixed payload path. A missing or empty
  # identity, a value that is no string, or a step on a path that is no map
  # fails with `:invalid_message_change`; a `previous_message.ts` that names
  # another message fails with `:conflicting_message_change`. The details
  # name payload paths and never a value, so no message text leaves through
  # an error.

  alias Jido.Connect.{Data, Error}
  alias Jido.Connect.Slack.MessageChange

  @channel_types [nil, "channel", "group", "im", "mpim"]

  # The event of each change trigger, with the subtype of its signals and
  # the channel types it accepts. Like `message.channels`, the public
  # channel family also takes an event without `channel_type`.
  @trigger_events %{
    "message.channels.changed" => {"message_changed", [nil, "channel"]},
    "message.channels.deleted" => {"message_deleted", [nil, "channel"]},
    "message.groups.changed" => {"message_changed", ["group"]},
    "message.groups.deleted" => {"message_deleted", ["group"]},
    "message.im.changed" => {"message_changed", ["im"]},
    "message.im.deleted" => {"message_deleted", ["im"]},
    "message.mpim.changed" => {"message_changed", ["mpim"]},
    "message.mpim.deleted" => {"message_deleted", ["mpim"]}
  }

  @identity_fields [
    team_id: ["team_id"],
    event_id: ["event_id"],
    channel: ["event", "channel"],
    channel_type: ["event", "channel_type"],
    notification_ts: ["event", "ts"],
    event_ts: ["event", "event_ts"]
  ]

  @edit_fields @identity_fields ++
                 [
                   ts: ["event", "message", "ts"],
                   thread_ts: ["event", "message", "thread_ts"],
                   user: ["event", "message", "user"],
                   bot_id: ["event", "message", "bot_id"],
                   app_id: ["event", "message", "app_id"],
                   editor: ["event", "message", "edited", "user"],
                   edited_ts: ["event", "message", "edited", "ts"],
                   text: ["event", "message", "text"]
                 ]

  @deletion_fields @identity_fields ++
                     [
                       ts: ["event", "deleted_ts"],
                       thread_ts: ["event", "previous_message", "thread_ts"],
                       user: ["event", "previous_message", "user"],
                       bot_id: ["event", "previous_message", "bot_id"],
                       app_id: ["event", "previous_message", "app_id"]
                     ]

  @tombstone_fields @identity_fields ++
                      [
                        ts: ["event", "message", "ts"],
                        thread_ts: ["event", "message", "thread_ts"],
                        user: ["event", "previous_message", "user"],
                        bot_id: ["event", "previous_message", "bot_id"],
                        app_id: ["event", "previous_message", "app_id"]
                      ]

  @tombstone_removal_fields @identity_fields ++
                              [
                                ts: ["event", "deleted_ts"],
                                thread_ts: ["event", "previous_message", "thread_ts"]
                              ]

  @previous ["event", "previous_message"]
  @previous_ts ["event", "previous_message", "ts"]
  @edited_ts ["event", "message", "edited", "ts"]
  @previous_edited_ts ["event", "previous_message", "edited", "ts"]
  @text ["event", "message", "text"]
  @previous_text ["event", "previous_message", "text"]

  @doc false
  def trigger_events, do: Map.keys(@trigger_events)

  @doc false
  def normalize_signal("message", payload) do
    change_signal(payload, MessageChange.subtypes(), @channel_types)
  end

  def normalize_signal(event, payload) when is_map_key(@trigger_events, event) do
    {subtype, channel_types} = Map.fetch!(@trigger_events, event)
    change_signal(payload, [subtype], channel_types)
  end

  defp change_signal(
         %{"type" => "event_callback", "event" => %{"type" => "message"} = event} = payload,
         subtypes,
         channel_types
       ) do
    with {:ok, kind} <- change_kind(event, subtypes),
         :ok <- require_channel_type(event, channel_types),
         :ok <- require_edit(payload, kind),
         fields = fields(kind, event),
         {:ok, attrs} <- attrs(payload, fields),
         {:ok, change} <- build(Map.put(attrs, :subtype, signal_subtype(kind)), fields),
         :ok <- require_same_source(payload, change, fields) do
      {:ok, to_signal(change)}
    end
  end

  defp change_signal(_payload, _subtypes, _channel_types) do
    {:error,
     Error.provider("Unsupported Slack event",
       provider: :slack,
       reason: :unsupported_event
     )}
  end

  # The change that `event` describes, if `subtypes` take it: an edit, a
  # deletion, or a tombstone. A trigger that takes only edits gets a
  # tombstone as an edit, which require_edit/2 rejects.
  defp change_kind(event, subtypes) do
    subtype = Data.get(event, "subtype")
    deletions? = "message_deleted" in subtypes

    cond do
      subtype == "message_deleted" and deletions? ->
        {:ok, :deletion}

      subtype == "message_changed" and deletions? and tombstone?(Data.get(event, "message")) ->
        {:ok, :tombstone}

      subtype == "message_changed" and "message_changed" in subtypes ->
        {:ok, :edit}

      true ->
        {:error,
         Error.provider("Unsupported Slack message subtype",
           provider: :slack,
           reason: :unsupported_message_subtype,
           details: %{subtype: subtype}
         )}
    end
  end

  defp tombstone?(message), do: is_map(message) and Data.get(message, "subtype") == "tombstone"

  defp signal_subtype(:edit), do: "message_changed"
  defp signal_subtype(_deletion), do: "message_deleted"

  defp require_channel_type(event, channel_types) do
    channel_type = Data.get(event, "channel_type")

    if channel_type in channel_types do
      :ok
    else
      {:error,
       Error.provider("Unsupported Slack message channel type",
         provider: :slack,
         reason: :unsupported_channel_type,
         details: %{channel_type: channel_type}
       )}
    end
  end

  # Slack also sends `message_changed` when it unfurls a link, updates a
  # thread parent's replies or leaves a tombstone. Only a new
  # `message.edited` marks an edit.
  defp require_edit(%{"event" => event} = payload, :edit) do
    case Data.get(event, "message") do
      %{} = message ->
        if is_nil(Data.get(message, "edited")) or tombstone?(message),
          do: {:error, not_an_edit()},
          else: require_new_edit(payload)

      # A message that is no map, which attrs/2 reports.
      _malformed ->
        :ok
    end
  end

  defp require_edit(_payload, _deletion), do: :ok

  # Slack keeps `edited` on a message after an edit, so a later unfurl or
  # reply count update repeats the last edit. A new edit has another
  # `edited.ts` than `previous_message`, or another text: two edits within
  # one second share their `edited.ts`. Without `previous_message`,
  # `message.edited` alone marks an edit.
  defp require_new_edit(payload) do
    case value_at(payload, @previous, []) do
      {:ok, %{}} ->
        with {:ok, edit} <- values_at(payload, [@edited_ts, @text]),
             {:ok, previous} <- values_at(payload, [@previous_edited_ts, @previous_text]) do
          if edit == previous, do: {:error, not_an_edit()}, else: :ok
        end

      # No `previous_message`, or one that is no map, which
      # require_same_source/3 reports.
      _none_or_malformed ->
        :ok
    end
  end

  defp values_at(payload, paths) do
    Enum.reduce_while(paths, {:ok, []}, fn path, {:ok, values} ->
      case value_at(payload, path, []) do
        {:ok, value} -> {:cont, {:ok, [value | values]}}
        {:error, _reason} = error -> {:halt, error}
      end
    end)
  end

  defp not_an_edit do
    Error.provider("Slack message change is no edit",
      provider: :slack,
      reason: :not_an_edit
    )
  end

  # A deletion reads no text: the deleted text is only in `previous_message`.
  defp fields(:edit, _event), do: @edit_fields
  defp fields(:tombstone, _event), do: @tombstone_fields

  defp fields(:deletion, event) do
    if tombstone?(Data.get(event, "previous_message")),
      do: @tombstone_removal_fields,
      else: @deletion_fields
  end

  defp attrs(payload, fields) do
    Enum.reduce_while(fields, {:ok, %{}}, fn {key, path}, {:ok, attrs} ->
      case value_at(payload, path, []) do
        {:ok, value} -> {:cont, {:ok, Map.put(attrs, key, blank_to_nil(key, value))}}
        {:error, _reason} = error -> {:halt, error}
      end
    end)
  end

  # The value at `path`, nil when a map on the way lacks the next key, or an
  # error that names the first step that is no map.
  defp value_at(value, [], _walked), do: {:ok, value}
  defp value_at(nil, _path, _walked), do: {:ok, nil}

  defp value_at(map, [key | rest], walked) when is_map(map),
    do: value_at(Data.get(map, key), rest, [key | walked])

  defp value_at(_other, _path, walked), do: {:error, invalid(Enum.reverse(walked))}

  # Like `Data.compact/1`, an empty ID or timestamp counts as absent. An
  # empty text is the text of the edit.
  defp blank_to_nil(:text, value), do: value
  defp blank_to_nil(_key, ""), do: nil
  defp blank_to_nil(_key, value), do: value

  defp build(attrs, fields) do
    case MessageChange.new(attrs) do
      {:ok, change} ->
        {:ok, change}

      {:error, [%Zoi.Error{path: [key | _rest]} | _errors]} ->
        {:error, invalid(Keyword.fetch!(fields, key))}
    end
  end

  # `previous_message`, when Slack sends it, must be the same message.
  defp require_same_source(payload, %MessageChange{ts: ts}, fields) do
    case value_at(payload, @previous_ts, []) do
      {:ok, previous} when previous in [nil, "", ts] ->
        :ok

      {:ok, previous} when is_binary(previous) ->
        {:error,
         Error.provider("Slack message change names two messages",
           provider: :slack,
           reason: :conflicting_message_change,
           details: %{
             field: path_name(Keyword.fetch!(fields, :ts)),
             conflicts_with: path_name(@previous_ts)
           }
         )}

      {:ok, _other} ->
        {:error, invalid(@previous_ts)}

      {:error, _reason} = error ->
        error
    end
  end

  defp path_name(path), do: Enum.join(path, ".")

  defp to_signal(%MessageChange{text: text} = change) do
    change
    |> Map.from_struct()
    |> Map.delete(:text)
    |> Data.compact()
    |> put_text(text)
  end

  defp put_text(signal, nil), do: signal
  defp put_text(signal, text), do: Map.put(signal, :text, text)

  defp invalid(path) do
    Error.provider("Slack message change is malformed",
      provider: :slack,
      reason: :invalid_message_change,
      details: %{field: path_name(path)}
    )
  end
end
