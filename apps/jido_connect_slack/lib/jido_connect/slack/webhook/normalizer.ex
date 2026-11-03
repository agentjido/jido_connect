defmodule Jido.Connect.Slack.Webhook.Normalizer do
  @moduledoc false

  alias Jido.Connect.{Data, Error, WebhookDelivery}
  alias Jido.Connect.Slack.MessageChange
  alias Jido.Connect.Slack.Webhook.{MessageChanges, SharedMessages, View}

  @human_message_subtypes ["file_share", "thread_broadcast"]
  @change_subtypes MessageChange.subtypes()
  @change_events MessageChanges.trigger_events()

  # The message triggers declare these as the enum of their `subtype` field.
  @doc false
  def human_message_subtypes, do: @human_message_subtypes

  def normalize_signal(%WebhookDelivery{event: event, payload: payload} = delivery) do
    with {:ok, signal} <- normalize_signal(event, payload) do
      {:ok, Map.put(signal, :delivery, delivery_metadata(delivery))}
    end
  end

  def normalize_signal(
        "app_mention",
        %{"type" => "event_callback", "event" => %{"type" => "app_mention"} = event} = payload
      ) do
    {:ok,
     Data.compact(%{
       team_id: Data.get(payload, "team_id"),
       event_id: Data.get(payload, "event_id"),
       channel: Data.get(event, "channel"),
       channel_type: Data.get(event, "channel_type"),
       user: Data.get(event, "user"),
       text: Data.get(event, "text"),
       ts: Data.get(event, "ts"),
       thread_ts: Data.get(event, "thread_ts")
     })}
  end

  # Edits and deletions take their own path; every other subtype stays with
  # the message triggers, which reject both.
  def normalize_signal(
        "message",
        %{
          "type" => "event_callback",
          "event" => %{"type" => "message", "subtype" => subtype}
        } = payload
      )
      when subtype in @change_subtypes do
    MessageChanges.normalize_signal("message", payload)
  end

  def normalize_signal(
        "message",
        %{"type" => "event_callback", "event" => %{"type" => "message"} = event} = payload
      ) do
    with :ok <- reject_message_subtype(event),
         :ok <- require_message_channel_type(event, [nil, "channel", "group", "im", "mpim"]) do
      message_signal(payload, event)
    end
  end

  def normalize_signal("message.channels", payload) do
    normalize_message_signal(payload, [nil, "channel"])
  end

  def normalize_signal("message.groups", payload) do
    normalize_message_signal(payload, ["group"])
  end

  def normalize_signal("message.im", payload) do
    normalize_message_signal(payload, ["im"])
  end

  def normalize_signal("message.mpim", payload) do
    normalize_message_signal(payload, ["mpim"])
  end

  def normalize_signal("message.thread_reply", payload) do
    normalize_thread_reply_signal(payload)
  end

  def normalize_signal(
        "reaction_added",
        %{"type" => "event_callback", "event" => %{"type" => "reaction_added"} = event} =
          payload
      ) do
    {:ok, reaction_signal(payload, event)}
  end

  def normalize_signal(
        "reaction_removed",
        %{"type" => "event_callback", "event" => %{"type" => "reaction_removed"} = event} =
          payload
      ) do
    {:ok, reaction_signal(payload, event)}
  end

  def normalize_signal(
        event_type,
        %{"type" => "event_callback", "event" => %{"type" => payload_event_type} = event} =
          payload
      )
      when event_type == payload_event_type and
             event_type in [
               "channel_created",
               "channel_rename",
               "channel_archive",
               "channel_unarchive",
               "member_joined_channel",
               "member_left_channel",
               "file_created",
               "file_shared",
               "file_public",
               "file_deleted",
               "file_change",
               "app_uninstalled",
               "tokens_revoked",
               "scope_denied",
               "app_home_opened"
             ] do
    {:ok, lifecycle_signal(payload, event)}
  end

  def normalize_signal(event, payload) when event in @change_events do
    MessageChanges.normalize_signal(event, payload)
  end

  def normalize_signal(event, _payload) do
    {:error,
     Error.provider("Unsupported Slack event",
       provider: :slack,
       reason: :unsupported_event,
       details: %{event: event}
     )}
  end

  def normalize_event(%{"type" => "event_callback", "event" => %{"type" => type}} = payload) do
    normalize_signal(type, payload)
  end

  def normalize_event(%{"type" => type}) do
    {:error,
     Error.provider("Unsupported Slack event",
       provider: :slack,
       reason: :unsupported_event,
       details: %{type: type}
     )}
  end

  def normalize_event(_payload) do
    {:error,
     Error.provider("Unsupported Slack event",
       provider: :slack,
       reason: :unsupported_event
     )}
  end

  def maybe_put_normalized_signal(%WebhookDelivery{} = delivery) do
    case normalize_signal(delivery) do
      {:ok, signal} -> WebhookDelivery.put_signal(delivery, signal)
      {:error, _reason} -> delivery
    end
  end

  defp delivery_metadata(%WebhookDelivery{} = delivery) do
    Data.compact(%{
      provider: delivery.provider,
      event: delivery.event,
      id: delivery.delivery_id,
      duplicate?: delivery.duplicate?,
      received_at: delivery.received_at
    })
  end

  # Slack marks a new message that a person writes with a file as
  # `file_share`, and a thread reply also sent to the channel as
  # `thread_broadcast`. Every other subtype, such as an edit, a deletion, a
  # join notice or a classic bot message, is no new human message.
  defp reject_message_subtype(event) do
    case Data.get(event, "subtype") do
      subtype when subtype in [nil, "" | @human_message_subtypes] ->
        :ok

      subtype ->
        {:error,
         Error.provider("Unsupported Slack message subtype",
           provider: :slack,
           reason: :unsupported_message_subtype,
           details: %{subtype: subtype}
         )}
    end
  end

  defp normalize_message_signal(
         %{"type" => "event_callback", "event" => %{"type" => "message"} = event} = payload,
         channel_types
       ) do
    with :ok <- reject_message_subtype(event),
         :ok <- require_message_channel_type(event, channel_types) do
      message_signal(payload, event)
    end
  end

  defp normalize_message_signal(_payload, _channel_types) do
    {:error,
     Error.provider("Unsupported Slack event",
       provider: :slack,
       reason: :unsupported_event
     )}
  end

  defp normalize_thread_reply_signal(
         %{"type" => "event_callback", "event" => %{"type" => "message"} = event} = payload
       ) do
    with :ok <- reject_message_subtype(event),
         :ok <- require_message_channel_type(event, [nil, "channel", "group", "im", "mpim"]),
         :ok <- require_thread_reply(event) do
      message_signal(payload, event)
    end
  end

  defp normalize_thread_reply_signal(_payload) do
    {:error,
     Error.provider("Unsupported Slack event",
       provider: :slack,
       reason: :unsupported_event
     )}
  end

  defp message_signal(payload, event) do
    signal =
      Data.compact(%{
        team_id: Data.get(payload, "team_id"),
        event_id: Data.get(payload, "event_id"),
        channel: Data.get(event, "channel"),
        channel_type: Data.get(event, "channel_type"),
        user: Data.get(event, "user"),
        text: Data.get(event, "text"),
        ts: Data.get(event, "ts"),
        thread_ts: Data.get(event, "thread_ts"),
        event_ts: Data.get(event, "event_ts"),
        subtype: Data.get(event, "subtype"),
        file_ids: file_ids(event)
      })
      |> Map.merge(View.from_payload(payload))

    case Data.get(event, "channel_type") do
      channel_type when channel_type in ["im", "mpim"] ->
        with {:ok, metadata} <- direct_message_metadata(event) do
          {:ok, Map.merge(signal, metadata)}
        end

      _other ->
        {:ok, signal}
    end
  end

  # Only the IDs; file metadata, content and links stay in the delivery payload.
  defp file_ids(event) do
    with "file_share" <- Data.get(event, "subtype"),
         files when is_list(files) <- Data.get(event, "files"),
         [_ | _] = ids <-
           for(file <- files, id = Data.get(file, "id"), is_binary(id) and id != "", do: id) do
      ids
    else
      _no_file_ids -> nil
    end
  end

  defp require_thread_reply(event) do
    thread_ts = Data.get(event, "thread_ts")
    ts = Data.get(event, "ts")

    cond do
      thread_ts in [nil, ""] ->
        {:error,
         Error.provider("Slack message is not a thread reply",
           provider: :slack,
           reason: :not_thread_reply
         )}

      thread_ts == ts ->
        {:error,
         Error.provider("Slack message is a thread root",
           provider: :slack,
           reason: :thread_root_message
         )}

      true ->
        :ok
    end
  end

  defp direct_message_metadata(event) do
    with {:ok, shared_messages} <- SharedMessages.from_event(event) do
      {:ok,
       Data.compact(%{
         user_team: Data.get(event, "user_team"),
         source_team: Data.get(event, "source_team"),
         sender: sender_metadata(event),
         conversation: conversation_metadata(event),
         shared_messages: shared_messages
       })}
    end
  end

  defp sender_metadata(event) do
    Data.compact(%{
      id: Data.get(event, "user"),
      team_id: Data.get(event, "user_team") || Data.get(event, "source_team")
    })
  end

  defp conversation_metadata(event) do
    Data.compact(%{
      id: Data.get(event, "channel"),
      type: Data.get(event, "channel_type")
    })
  end

  defp reaction_signal(payload, event) do
    item = reaction_item(event)

    Data.compact(%{
      team_id: Data.get(payload, "team_id"),
      event_id: Data.get(payload, "event_id"),
      user: Data.get(event, "user"),
      reaction: Data.get(event, "reaction"),
      item_user: Data.get(event, "item_user"),
      item: item,
      item_type: Data.get(item, "type"),
      channel: Data.get(item, "channel"),
      ts: Data.get(item, "ts"),
      file: Data.get(item, "file"),
      file_comment: Data.get(item, "file_comment"),
      event_ts: Data.get(event, "event_ts"),
      actor: reaction_actor(payload, event),
      item_owner: reaction_item_owner(payload, event)
    })
  end

  defp reaction_item(event) do
    case Data.get(event, "item") do
      item when is_map(item) -> Data.compact(item)
      _other -> %{}
    end
  end

  defp reaction_actor(payload, event) do
    Data.compact(%{
      id: Data.get(event, "user"),
      team_id: Data.get(payload, "team_id")
    })
  end

  defp reaction_item_owner(payload, event) do
    Data.compact(%{
      id: Data.get(event, "item_user"),
      team_id: Data.get(payload, "team_id")
    })
  end

  defp lifecycle_signal(payload, %{"type" => event_type} = event)
       when event_type in [
              "member_joined_channel",
              "member_left_channel"
            ] do
    Data.compact(%{
      team_id: Data.get(payload, "team_id"),
      event_id: Data.get(payload, "event_id"),
      channel_id: channel_id(event),
      channel: Data.get(event, "channel"),
      channel_type: Data.get(event, "channel_type"),
      user: Data.get(event, "user"),
      inviter: Data.get(event, "inviter"),
      event_ts: Data.get(event, "event_ts"),
      actor: channel_actor(payload, event),
      inviter_user: channel_inviter(payload, event)
    })
  end

  defp lifecycle_signal(payload, %{"type" => event_type} = event)
       when event_type in [
              "channel_created",
              "channel_rename",
              "channel_archive",
              "channel_unarchive"
            ] do
    Data.compact(%{
      team_id: Data.get(payload, "team_id"),
      event_id: Data.get(payload, "event_id"),
      channel_id: channel_id(event),
      channel: channel_metadata(event),
      user: Data.get(event, "user"),
      event_ts: Data.get(event, "event_ts"),
      actor: channel_actor(payload, event)
    })
  end

  defp lifecycle_signal(payload, %{"type" => "app_uninstalled"}) do
    Data.compact(%{
      team_id: Data.get(payload, "team_id"),
      event_id: Data.get(payload, "event_id"),
      api_app_id: Data.get(payload, "api_app_id"),
      event_time: Data.get(payload, "event_time"),
      authorizations: Data.get(payload, "authorizations")
    })
  end

  defp lifecycle_signal(payload, %{"type" => "tokens_revoked"} = event) do
    tokens = token_revocation_metadata(event)

    Data.compact(%{
      team_id: Data.get(payload, "team_id"),
      event_id: Data.get(payload, "event_id"),
      api_app_id: Data.get(payload, "api_app_id"),
      event_time: Data.get(payload, "event_time"),
      tokens: tokens,
      oauth_user_ids: Data.get(tokens, "oauth"),
      bot_user_ids: Data.get(tokens, "bot")
    })
  end

  defp lifecycle_signal(payload, %{"type" => "scope_denied"} = event) do
    Data.compact(%{
      team_id: Data.get(payload, "team_id"),
      event_id: Data.get(payload, "event_id"),
      api_app_id: Data.get(payload, "api_app_id"),
      event_time: Data.get(payload, "event_time"),
      scope: Data.get(event, "scope"),
      scopes: Data.get(event, "scopes"),
      user: Data.get(event, "user"),
      trigger_id: Data.get(event, "trigger_id"),
      event_ts: Data.get(event, "event_ts")
    })
  end

  defp lifecycle_signal(payload, %{"type" => "app_home_opened"} = event) do
    Data.compact(%{
      team_id: Data.get(payload, "team_id"),
      event_id: Data.get(payload, "event_id"),
      api_app_id: Data.get(payload, "api_app_id"),
      user: Data.get(event, "user"),
      channel: Data.get(event, "channel"),
      tab: Data.get(event, "tab"),
      view: app_home_view(event),
      event_ts: Data.get(event, "event_ts"),
      actor: app_home_actor(payload, event),
      conversation: app_home_conversation(event)
    })
  end

  defp lifecycle_signal(payload, event), do: file_signal(payload, event)

  defp channel_id(event) do
    case Data.get(event, "channel") do
      channel_id when is_binary(channel_id) -> channel_id
      channel when is_map(channel) -> Data.get(channel, "id")
      _other -> nil
    end
  end

  defp channel_metadata(event) do
    case Data.get(event, "channel") do
      channel when is_map(channel) -> Data.compact(channel)
      _other -> nil
    end
  end

  defp channel_actor(payload, event) do
    channel = channel_metadata(event) || %{}

    Data.compact(%{
      id: Data.get(event, "user") || Data.get(channel, "creator"),
      team_id: Data.get(payload, "team_id")
    })
  end

  defp channel_inviter(payload, event) do
    case Data.get(event, "inviter") do
      inviter when is_binary(inviter) and inviter != "" ->
        Data.compact(%{
          id: inviter,
          team_id: Data.get(payload, "team_id")
        })

      _other ->
        nil
    end
  end

  defp token_revocation_metadata(event) do
    case Data.get(event, "tokens") do
      tokens when is_map(tokens) -> Data.compact(tokens)
      _other -> %{}
    end
  end

  defp app_home_view(event) do
    case Data.get(event, "view") do
      view when is_map(view) -> Data.compact(view)
      _other -> nil
    end
  end

  defp app_home_actor(payload, event) do
    Data.compact(%{
      id: Data.get(event, "user"),
      team_id: Data.get(payload, "team_id")
    })
  end

  defp app_home_conversation(event) do
    Data.compact(%{
      id: Data.get(event, "channel"),
      type: "app_home",
      tab: Data.get(event, "tab")
    })
  end

  defp file_signal(payload, event) do
    Data.compact(%{
      team_id: Data.get(payload, "team_id"),
      event_id: Data.get(payload, "event_id"),
      file_id: Data.get(event, "file_id"),
      file: file_metadata(event),
      user_id: Data.get(event, "user_id"),
      channel_id: Data.get(event, "channel_id"),
      event_ts: Data.get(event, "event_ts"),
      actor: file_actor(payload, event)
    })
  end

  defp file_metadata(event) do
    case Data.get(event, "file") do
      file when is_map(file) -> Data.compact(file)
      _other -> nil
    end
  end

  defp file_actor(payload, event) do
    Data.compact(%{
      id: Data.get(event, "user_id"),
      team_id: Data.get(payload, "team_id")
    })
  end

  defp require_message_channel_type(event, channel_types) do
    if Data.get(event, "channel_type") in channel_types do
      :ok
    else
      {:error,
       Error.provider("Unsupported Slack message channel type",
         provider: :slack,
         reason: :unsupported_channel_type,
         details: %{channel_type: Data.get(event, "channel_type")}
       )}
    end
  end
end
