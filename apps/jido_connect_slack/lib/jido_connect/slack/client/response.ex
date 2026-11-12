defmodule Jido.Connect.Slack.Client.Response do
  @moduledoc "Slack Web API success and error response handling."

  alias Jido.Connect.{Data, Error, ProviderResponse}
  alias Jido.Connect.Slack.Client.{Normalizer, Transport}

  import Normalizer

  def handle_channel_list_response({:ok, %{status: status, body: %{"ok" => true} = body}})
      when status in 200..299 do
    with channels when is_list(channels) <- Map.get(body, "channels", []),
         true <- Enum.all?(channels, &is_map/1) do
      {:ok,
       %{
         channels: Enum.map(channels, &normalize_channel/1),
         next_cursor: get_in(body, ["response_metadata", "next_cursor"]) || ""
       }}
    else
      _other ->
        Transport.invalid_success_response("Slack channel list response was invalid", body)
    end
  end

  def handle_channel_list_response(response), do: handle_error_response(response)

  def handle_thread_replies_response(
        {:ok, %{status: status, body: %{"ok" => true} = body}},
        params
      )
      when status in 200..299 do
    with messages when is_list(messages) <- Map.get(body, "messages", []),
         true <- Enum.all?(messages, &is_map/1) do
      {:ok,
       %{
         channel: Data.get(params, :channel),
         thread_ts: Data.get(params, :ts),
         messages: messages,
         next_cursor: get_in(body, ["response_metadata", "next_cursor"]) || "",
         has_more: Data.get(body, "has_more", false)
       }}
    else
      _other ->
        Transport.invalid_success_response("Slack thread replies response was invalid", body)
    end
  end

  def handle_thread_replies_response(response, _params), do: handle_error_response(response)

  def handle_conversation_history_response(
        {:ok, %{status: status, body: %{"ok" => true} = body}},
        params
      )
      when status in 200..299 do
    with messages when is_list(messages) <- Map.get(body, "messages"),
         {:ok, messages} <- normalize_history_messages(messages, params),
         next_cursor when is_binary(next_cursor) <-
           get_in(body, ["response_metadata", "next_cursor"]) || "",
         has_more when is_boolean(has_more) <- Map.get(body, "has_more", false),
         {:ok, page} <-
           put_is_limited(
             %{messages: messages, next_cursor: next_cursor, has_more: has_more},
             body
           ) do
      {:ok, page}
    else
      _other ->
        Transport.invalid_success_response(
          "Slack conversation history response was invalid",
          body
        )
    end
  end

  def handle_conversation_history_response(response, _params),
    do: handle_error_response(response)

  def handle_search_messages_response({:ok, %{status: status, body: %{"ok" => true} = body}})
      when status in 200..299 do
    with messages when is_map(messages) <- Map.get(body, "messages", %{}),
         matches when is_list(matches) <- Map.get(messages, "matches", []),
         true <- Enum.all?(matches, &is_map/1) do
      {:ok,
       %{
         query: Data.get(body, "query"),
         messages: matches,
         total_count: search_total_count(messages),
         pagination: Data.get(messages, "pagination", %{}),
         paging: Data.get(messages, "paging", %{}),
         next_cursor: get_in(body, ["response_metadata", "next_cursor"]) || ""
       }}
    else
      _other ->
        Transport.invalid_success_response("Slack message search response was invalid", body)
    end
  end

  def handle_search_messages_response(response), do: handle_error_response(response)

  def handle_search_files_response({:ok, %{status: status, body: %{"ok" => true} = body}})
      when status in 200..299 do
    with files when is_map(files) <- Map.get(body, "files", %{}),
         matches when is_list(matches) <- Map.get(files, "matches", []),
         true <- Enum.all?(matches, &is_map/1) do
      {:ok,
       %{
         query: Data.get(body, "query"),
         files: matches,
         total_count: search_total_count(files),
         pagination: Data.get(files, "pagination", %{}),
         paging: Data.get(files, "paging", %{}),
         next_cursor: get_in(body, ["response_metadata", "next_cursor"]) || ""
       }}
    else
      _other -> Transport.invalid_success_response("Slack file search response was invalid", body)
    end
  end

  def handle_search_files_response(response), do: handle_error_response(response)

  def handle_conversation_info_response(
        {:ok, %{status: status, body: %{"ok" => true} = body}},
        params
      )
      when status in 200..299 do
    case Map.get(body, "channel") do
      conversation when is_map(conversation) ->
        {:ok,
         %{
           channel: Data.get(conversation, "id", Data.get(params, :channel)),
           conversation: conversation
         }}

      _other ->
        Transport.invalid_success_response("Slack conversation info response was invalid", body)
    end
  end

  def handle_conversation_info_response(response, _params), do: handle_error_response(response)

  def handle_create_channel_response({:ok, %{status: status, body: %{"ok" => true} = body}})
      when status in 200..299 do
    case Data.get(body, "channel") do
      channel when is_map(channel) ->
        {:ok, %{channel: normalize_channel(channel)}}

      _other ->
        Transport.invalid_success_response("Slack channel create response was invalid", body)
    end
  end

  def handle_create_channel_response(response), do: handle_error_response(response)

  def handle_archive_conversation_response(
        {:ok, %{status: status, body: %{"ok" => true}}},
        params
      )
      when status in 200..299 do
    {:ok, %{channel: Data.get(params, :channel)}}
  end

  def handle_archive_conversation_response(response, _params),
    do: handle_error_response(response)

  def handle_unarchive_conversation_response(
        {:ok, %{status: status, body: %{"ok" => true}}},
        params
      )
      when status in 200..299 do
    {:ok, %{channel: Data.get(params, :channel)}}
  end

  def handle_unarchive_conversation_response(response, _params),
    do: handle_error_response(response)

  def handle_rename_conversation_response({:ok, %{status: status, body: %{"ok" => true} = body}})
      when status in 200..299 do
    case Data.get(body, "channel") do
      channel when is_map(channel) ->
        {:ok, %{channel: normalize_channel(channel)}}

      _other ->
        Transport.invalid_success_response("Slack channel rename response was invalid", body)
    end
  end

  def handle_rename_conversation_response(response), do: handle_error_response(response)

  def handle_invite_conversation_response(
        {:ok, %{status: status, body: %{"ok" => true} = body}},
        params
      )
      when status in 200..299 do
    case Data.get(body, "channel") do
      channel when is_map(channel) ->
        {:ok,
         %{
           channel: normalize_channel(channel),
           invited_users: invited_users(params, []),
           failed_users: [],
           partial_failure: false
         }}

      _other ->
        Transport.invalid_success_response("Slack conversation invite response was invalid", body)
    end
  end

  def handle_invite_conversation_response(
        {:ok, %{status: status, body: %{"ok" => false, "errors" => errors} = body}},
        params
      )
      when status in 200..299 and is_list(errors) do
    failed_users = normalize_invite_errors(errors)

    if Data.get(params, :force, false) do
      {:ok,
       %{
         channel: %{id: Data.get(params, :channel)},
         invited_users: invited_users(params, failed_users),
         failed_users: failed_users,
         partial_failure: true
       }}
    else
      {:error,
       Error.provider("Slack conversation invite partially failed",
         provider: :slack,
         status: status,
         reason: Data.get(body, "error"),
         details: %{body: body, failed_users: failed_users}
       )}
    end
  end

  def handle_invite_conversation_response(response, _params), do: handle_error_response(response)

  def handle_kick_conversation_response(
        {:ok, %{status: status, body: %{"ok" => true}}},
        params
      )
      when status in 200..299 do
    {:ok,
     %{
       channel: Data.get(params, :channel),
       user: Data.get(params, :user)
     }}
  end

  def handle_kick_conversation_response(response, _params), do: handle_error_response(response)

  def handle_open_conversation_response({:ok, %{status: status, body: %{"ok" => true} = body}})
      when status in 200..299 do
    case Data.get(body, "channel") do
      conversation when is_map(conversation) ->
        conversation = normalize_conversation(conversation)

        {:ok,
         %{
           channel: Data.get(conversation, :id),
           conversation: conversation
         }}

      _other ->
        Transport.invalid_success_response("Slack conversation open response was invalid", body)
    end
  end

  def handle_open_conversation_response(response), do: handle_error_response(response)

  def handle_conversation_members_response(
        {:ok, %{status: status, body: %{"ok" => true} = body}},
        params
      )
      when status in 200..299 do
    with members when is_list(members) <- Map.get(body, "members", []),
         true <- Enum.all?(members, &is_binary/1) do
      {:ok,
       %{
         channel: Data.get(params, :channel),
         members: members,
         next_cursor: get_in(body, ["response_metadata", "next_cursor"]) || ""
       }}
    else
      _other ->
        Transport.invalid_success_response(
          "Slack conversation members response was invalid",
          body
        )
    end
  end

  def handle_conversation_members_response(response, _params),
    do: handle_error_response(response)

  def handle_message_response({:ok, %{status: status, body: %{"ok" => true} = body}})
      when status in 200..299 do
    {:ok,
     %{
       channel: Data.get(body, "channel"),
       ts: Data.get(body, "ts"),
       message: Data.get(body, "message") || %{}
     }}
  end

  def handle_message_response(response), do: handle_error_response(response)

  def handle_ephemeral_message_response(
        {:ok, %{status: status, body: %{"ok" => true} = body}},
        attrs
      )
      when status in 200..299 do
    case Data.get(body, "message_ts") do
      message_ts when is_binary(message_ts) ->
        {:ok,
         %{
           channel: Data.get(attrs, :channel),
           user: Data.get(attrs, :user),
           message_ts: message_ts
         }}

      _other ->
        Transport.invalid_success_response("Slack ephemeral message response was invalid", body)
    end
  end

  def handle_ephemeral_message_response(response, _attrs), do: handle_error_response(response)

  def handle_scheduled_message_response({:ok, %{status: status, body: %{"ok" => true} = body}})
      when status in 200..299 do
    with channel when is_binary(channel) <- Data.get(body, "channel"),
         scheduled_message_id when is_binary(scheduled_message_id) <-
           Data.get(body, "scheduled_message_id"),
         post_at when is_integer(post_at) <- normalize_post_at(Data.get(body, "post_at")) do
      {:ok,
       %{
         channel: channel,
         scheduled_message_id: scheduled_message_id,
         post_at: post_at,
         message: Data.get(body, "message") || %{}
       }}
    else
      _other ->
        Transport.invalid_success_response("Slack scheduled message response was invalid", body)
    end
  end

  def handle_scheduled_message_response(response), do: handle_error_response(response)

  def handle_delete_scheduled_message_response(
        {:ok, %{status: status, body: %{"ok" => true}}},
        attrs
      )
      when status in 200..299 do
    {:ok,
     %{
       channel: Data.get(attrs, :channel),
       scheduled_message_id: Data.get(attrs, :scheduled_message_id)
     }}
  end

  def handle_delete_scheduled_message_response(response, _attrs),
    do: handle_error_response(response)

  def handle_delete_message_response({:ok, %{status: status, body: %{"ok" => true} = body}})
      when status in 200..299 do
    {:ok,
     %{
       channel: Data.get(body, "channel"),
       ts: Data.get(body, "ts")
     }}
  end

  def handle_delete_message_response(response), do: handle_error_response(response)

  def handle_delete_file_response({:ok, %{status: status, body: %{"ok" => true}}}, attrs)
      when status in 200..299 do
    {:ok, %{file_id: Data.get(attrs, :file_id)}}
  end

  def handle_delete_file_response(response, _attrs), do: handle_error_response(response)

  def handle_add_reaction_response({:ok, %{status: status, body: %{"ok" => true}}}, attrs)
      when status in 200..299 do
    {:ok,
     %{
       channel: Data.get(attrs, :channel),
       timestamp: Data.get(attrs, :timestamp),
       name: Data.get(attrs, :name)
     }}
  end

  def handle_add_reaction_response(response, _attrs), do: handle_error_response(response)

  def handle_remove_reaction_response({:ok, %{status: status, body: %{"ok" => true}}}, attrs)
      when status in 200..299 do
    {:ok,
     %{
       channel: Data.get(attrs, :channel),
       timestamp: Data.get(attrs, :timestamp),
       name: Data.get(attrs, :name)
     }}
  end

  def handle_remove_reaction_response(response, _attrs), do: handle_error_response(response)

  def handle_get_reactions_response(
        {:ok, %{status: status, body: %{"ok" => true} = body}},
        params
      )
      when status in 200..299 do
    with type when is_binary(type) <- Data.get(body, "type"),
         {:ok, target} <- reactions_target(type, body) do
      {:ok,
       target
       |> Map.merge(%{
         type: type,
         channel: Data.get(body, "channel", Data.get(params, :channel)),
         timestamp: Data.get(body, "timestamp", Data.get(params, :timestamp)),
         file_id: Data.get(params, :file),
         file_comment_id: Data.get(params, :file_comment)
       })
       |> Map.put(:reactions, target_reactions(target))
       |> Data.compact()}
    else
      _other -> Transport.invalid_success_response("Slack reactions response was invalid", body)
    end
  end

  def handle_get_reactions_response(response, _params), do: handle_error_response(response)

  def handle_pin_list_response(
        {:ok, %{status: status, body: %{"ok" => true} = body}},
        params
      )
      when status in 200..299 do
    with items when is_list(items) <- Map.get(body, "items", []),
         true <- Enum.all?(items, &is_map/1) do
      {:ok,
       %{
         channel: Data.get(params, :channel),
         items: Enum.map(items, &normalize_pinned_item/1)
       }}
    else
      _other -> Transport.invalid_success_response("Slack pin list response was invalid", body)
    end
  end

  def handle_pin_list_response(response, _params), do: handle_error_response(response)

  def handle_add_pin_response({:ok, %{status: status, body: %{"ok" => true}}}, attrs)
      when status in 200..299 do
    {:ok,
     %{
       type: "message",
       channel: Data.get(attrs, :channel),
       timestamp: Data.get(attrs, :timestamp)
     }}
  end

  def handle_add_pin_response(response, _attrs), do: handle_error_response(response)

  def handle_remove_pin_response({:ok, %{status: status, body: %{"ok" => true}}}, attrs)
      when status in 200..299 do
    {:ok,
     %{
       type: "message",
       channel: Data.get(attrs, :channel),
       timestamp: Data.get(attrs, :timestamp)
     }}
  end

  def handle_remove_pin_response(response, _attrs), do: handle_error_response(response)

  def normalize_pinned_item(item) do
    message = Data.get(item, "message")
    file = Data.get(item, "file")
    file_comment = Data.get(item, "comment")

    %{
      type: Data.get(item, "type"),
      channel: Data.get(item, "channel", Data.get(message, "channel")),
      timestamp: Data.get(item, "timestamp", Data.get(message, "ts")),
      created: Data.get(item, "created"),
      created_by: Data.get(item, "created_by"),
      message: message,
      file: file,
      file_comment: file_comment
    }
    |> Data.compact()
  end

  def reactions_target("message", body) do
    case Data.get(body, "message") do
      message when is_map(message) -> {:ok, %{message: message}}
      _other -> {:error, :invalid_target}
    end
  end

  def reactions_target("file", body) do
    case Data.get(body, "file") do
      file when is_map(file) ->
        {:ok, %{file: file, file_id: Data.get(file, "id")}}

      _other ->
        {:error, :invalid_target}
    end
  end

  def reactions_target("file_comment", body) do
    with file when is_map(file) <- Data.get(body, "file"),
         file_comment when is_map(file_comment) <- Data.get(body, "comment") do
      {:ok,
       %{
         file: file,
         file_comment: file_comment,
         file_id: Data.get(file, "id"),
         file_comment_id: Data.get(file_comment, "id")
       }}
    else
      _other -> {:error, :invalid_target}
    end
  end

  def reactions_target(_type, _body), do: {:error, :invalid_target}

  def target_reactions(%{message: message}), do: Data.get(message, "reactions", [])

  def target_reactions(%{file_comment: file_comment}),
    do: Data.get(file_comment, "reactions", [])

  def target_reactions(%{file: file}), do: Data.get(file, "reactions", [])
  def target_reactions(_target), do: []

  def invited_users(params, failed_users) do
    failed_user_ids = MapSet.new(failed_users, &Data.get(&1, :user))

    params
    |> Data.get(:users, [])
    |> List.wrap()
    |> Enum.reject(&MapSet.member?(failed_user_ids, &1))
  end

  def normalize_invite_errors(errors) do
    errors
    |> Enum.filter(&is_map/1)
    |> Enum.map(fn error ->
      %{
        user: Data.get(error, "user"),
        error: Data.get(error, "error"),
        ok: Data.get(error, "ok")
      }
      |> Data.compact()
    end)
  end

  def normalize_post_at(post_at) when is_integer(post_at), do: post_at

  def normalize_post_at(post_at) when is_binary(post_at) do
    case Integer.parse(post_at) do
      {integer, ""} -> integer
      _other -> nil
    end
  end

  def normalize_post_at(_post_at), do: nil

  def search_total_count(messages) do
    messages
    |> Data.get("pagination", %{})
    |> Data.get("total_count", Data.get(messages, "total"))
  end

  def handle_upload_url_response({:ok, %{status: status, body: %{"ok" => true} = body}})
      when status in 200..299 do
    with upload_url when is_binary(upload_url) <- Data.get(body, "upload_url"),
         file_id when is_binary(file_id) <- Data.get(body, "file_id") do
      {:ok, %{upload_url: upload_url, file_id: file_id}}
    else
      _other -> Transport.invalid_success_response("Slack upload URL response was invalid", body)
    end
  end

  def handle_upload_url_response(response), do: handle_error_response(response)

  def handle_file_content_response({:ok, %{status: status} = response})
      when status in 200..299 do
    {:ok, response}
  end

  def handle_file_content_response({:ok, %{status: status, body: body}}) do
    Transport.provider_error({:ok, %{status: status, body: body}},
      provider: :slack,
      message: "Slack file upload failed"
    )
  end

  def handle_file_content_response({:error, _reason} = response) do
    Transport.provider_error(response, provider: :slack, message: "Slack file upload failed")
  end

  def handle_complete_upload_response(
        {:ok, %{status: status, body: %{"ok" => true} = body}},
        upload
      )
      when status in 200..299 do
    files = Data.get(body, "files", [])

    if is_list(files) and Enum.all?(files, &is_map/1) do
      {:ok, %{file_id: Data.get(upload, :file_id), files: files}}
    else
      Transport.invalid_success_response("Slack complete upload response was invalid", body)
    end
  end

  def handle_complete_upload_response(response, _upload), do: handle_error_response(response)

  def handle_share_file_response({:ok, %{status: status, body: %{"ok" => true} = body}}, attrs)
      when status in 200..299 do
    files = Data.get(body, "files", [])

    if is_list(files) and Enum.all?(files, &is_map/1) do
      {:ok, %{file_id: Data.get(attrs, :file_id), files: files}}
    else
      Transport.invalid_success_response("Slack share file response was invalid", body)
    end
  end

  def handle_share_file_response(response, _attrs), do: handle_error_response(response)

  def handle_user_list_response({:ok, %{status: status, body: %{"ok" => true} = body}})
      when status in 200..299 do
    with users when is_list(users) <- Map.get(body, "members", []),
         true <- Enum.all?(users, &is_map/1) do
      {:ok,
       %{
         users: Enum.map(users, &normalize_user/1),
         next_cursor: get_in(body, ["response_metadata", "next_cursor"]) || ""
       }}
    else
      _other -> Transport.invalid_success_response("Slack user list response was invalid", body)
    end
  end

  def handle_user_list_response(response), do: handle_error_response(response)

  def handle_user_info_response({:ok, %{status: status, body: %{"ok" => true} = body}})
      when status in 200..299 do
    case Data.get(body, "user") do
      user when is_map(user) -> {:ok, %{user: normalize_user_info(user)}}
      _other -> Transport.invalid_success_response("Slack user info response was invalid", body)
    end
  end

  def handle_user_info_response(response), do: handle_error_response(response)

  def handle_lookup_user_by_email_response(
        {:ok, %{body: %{"ok" => false, "error" => "users_not_found"} = body}}
      ) do
    {:error,
     Error.provider("Slack user was not found",
       provider: :slack,
       status: 404,
       reason: :not_found,
       details: %{body: body}
     )}
  end

  def handle_lookup_user_by_email_response({:ok, %{status: status, body: %{"ok" => true} = body}})
      when status in 200..299 do
    case Data.get(body, "user") do
      user when is_map(user) ->
        {:ok, %{user: normalize_user_info(user)}}

      _other ->
        Transport.invalid_success_response(
          "Slack user lookup by email response was invalid",
          body
        )
    end
  end

  def handle_lookup_user_by_email_response(response), do: handle_error_response(response)

  def handle_map_response({:ok, %{status: status, body: %{"ok" => true} = body}})
      when status in 200..299 do
    {:ok, body}
  end

  def handle_map_response(response), do: handle_error_response(response)

  def handle_team_info_response({:ok, %{status: status, body: %{"ok" => true} = body}})
      when status in 200..299 do
    case Data.get(body, "team") do
      team when is_map(team) -> {:ok, %{team: team}}
      _other -> Transport.invalid_success_response("Slack team info response was invalid", body)
    end
  end

  def handle_team_info_response(response), do: handle_error_response(response)

  # Slack reports most failures, rate limits included, as `ok: false`. This
  # clause keeps the `Retry-After` header in `details.retry_after`. The next
  # clause and `handle_file_content_response/1` pass only status and body on,
  # so their errors carry no `retry_after`.
  def handle_error_response({:ok, %{status: status, body: %{"ok" => false} = body} = response}) do
    Error.provider("Slack API request failed",
      provider: :slack,
      status: status,
      reason: Data.get(body, "error"),
      details: %{body: body, retry_after: retry_after(response)}
    )
    |> then(&{:error, &1})
  end

  def handle_error_response({:ok, %{status: status, body: body}}) do
    Transport.provider_error({:ok, %{status: status, body: body}},
      provider: :slack,
      message: "Slack HTTP request failed"
    )
  end

  def handle_error_response({:error, _reason} = response),
    do: Transport.provider_error(response, provider: :slack, message: "Slack request failed")

  defp retry_after(response),
    do: ProviderResponse.from_result!(:slack, {:ok, response}).retry_after

  defp normalize_history_messages(messages, params) do
    Enum.reduce_while(messages, {:ok, []}, fn message, {:ok, normalized} ->
      case normalize_history_message(message, params) do
        {:ok, message} -> {:cont, {:ok, [message | normalized]}}
        {:error, _reason} = error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, normalized} -> {:ok, Enum.reverse(normalized)}
      error -> error
    end
  end

  # Slack sends `is_limited` only for some workspaces; keep it only then.
  defp put_is_limited(page, body) do
    case Map.fetch(body, "is_limited") do
      :error ->
        {:ok, page}

      {:ok, is_limited} when is_boolean(is_limited) ->
        {:ok, Map.put(page, :is_limited, is_limited)}

      {:ok, _other} ->
        {:error, :invalid_is_limited}
    end
  end
end
