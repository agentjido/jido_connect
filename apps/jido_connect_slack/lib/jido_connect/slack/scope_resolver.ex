defmodule Jido.Connect.Slack.ScopeResolver do
  @moduledoc """
  Resolves Slack scopes whose requirements depend on action input.

  Slack's conversations endpoints change required scopes based on the requested
  conversation types, so the static DSL scopes represent the default public
  channel case and this resolver tightens checks for private channels, DMs, and
  multi-person DMs. Slack history reads use the same conversation distinctions.

  A supplied `conversation_type` never lowers the scope that the channel ID or
  the participant set requires. It decides only where they leave the
  conversation type open: for `C` IDs, which Slack gives to public channels,
  private channels and group DMs, and when no channel is given.
  """

  @conversation_type_scopes %{
    "public_channel" => "channels:read",
    "private_channel" => "groups:read",
    "im" => "im:read",
    "mpim" => "mpim:read"
  }

  @conversation_history_scopes %{
    "public_channel" => "channels:history",
    "private_channel" => "groups:history",
    "im" => "im:history",
    "mpim" => "mpim:history"
  }

  @conversation_write_scopes %{
    "im" => "im:write",
    "mpim" => "mpim:write"
  }

  @conversation_mark_scopes %{
    "public_channel" => "channels:write",
    "private_channel" => "groups:write",
    "im" => "im:write",
    "mpim" => "mpim:write"
  }

  @channel_create_scopes %{
    false => "channels:manage",
    true => "groups:write"
  }

  @conversation_archive_scopes %{
    "public_channel" => "channels:manage",
    "private_channel" => "groups:write",
    "im" => "im:write",
    "mpim" => "mpim:write"
  }

  def required_scopes(%{id: "slack.channel.list"}, input, _connection) do
    input
    |> requested_types()
    |> Enum.map(&Map.get(@conversation_type_scopes, &1, "channels:read"))
    |> Enum.uniq()
  end

  def required_scopes(%{action_id: "slack.channel.list"}, input, connection) do
    required_scopes(%{id: "slack.channel.list"}, input, connection)
  end

  def required_scopes(%{id: "slack.conversation.info"}, input, _connection) do
    input
    |> requested_conversation_type()
    |> conversation_read_scope()
    |> List.wrap()
  end

  def required_scopes(%{action_id: "slack.conversation.info"}, input, connection) do
    required_scopes(%{id: "slack.conversation.info"}, input, connection)
  end

  def required_scopes(%{id: "slack.channel.create"}, input, _connection) do
    input
    |> private_channel?()
    |> then(&Map.fetch!(@channel_create_scopes, &1))
    |> List.wrap()
  end

  def required_scopes(%{action_id: "slack.channel.create"}, input, connection) do
    required_scopes(%{id: "slack.channel.create"}, input, connection)
  end

  def required_scopes(%{id: "slack.channel.archive"}, input, _connection) do
    input
    |> requested_conversation_type()
    |> then(&Map.get(@conversation_archive_scopes, &1, "channels:manage"))
    |> List.wrap()
  end

  def required_scopes(%{action_id: "slack.channel.archive"}, input, connection) do
    required_scopes(%{id: "slack.channel.archive"}, input, connection)
  end

  def required_scopes(%{id: "slack.channel.unarchive"}, input, _connection) do
    input
    |> requested_conversation_type()
    |> then(&Map.get(@conversation_archive_scopes, &1, "channels:manage"))
    |> List.wrap()
  end

  def required_scopes(%{action_id: "slack.channel.unarchive"}, input, connection) do
    required_scopes(%{id: "slack.channel.unarchive"}, input, connection)
  end

  def required_scopes(%{id: "slack.channel.rename"}, input, _connection) do
    input
    |> requested_conversation_type()
    |> then(&Map.get(@conversation_archive_scopes, &1, "channels:manage"))
    |> List.wrap()
  end

  def required_scopes(%{action_id: "slack.channel.rename"}, input, connection) do
    required_scopes(%{id: "slack.channel.rename"}, input, connection)
  end

  def required_scopes(%{id: "slack.conversation.invite"}, input, _connection) do
    input
    |> requested_conversation_type()
    |> then(&Map.get(@conversation_archive_scopes, &1, "channels:manage"))
    |> List.wrap()
  end

  def required_scopes(%{action_id: "slack.conversation.invite"}, input, connection) do
    required_scopes(%{id: "slack.conversation.invite"}, input, connection)
  end

  def required_scopes(%{id: "slack.conversation.kick"}, input, _connection) do
    input
    |> requested_conversation_type()
    |> then(&Map.get(@conversation_archive_scopes, &1, "channels:manage"))
    |> List.wrap()
  end

  def required_scopes(%{action_id: "slack.conversation.kick"}, input, connection) do
    required_scopes(%{id: "slack.conversation.kick"}, input, connection)
  end

  def required_scopes(%{id: "slack.conversation.open"}, input, _connection) do
    input
    |> requested_open_conversation_type()
    |> conversation_write_scope()
    |> List.wrap()
  end

  def required_scopes(%{action_id: "slack.conversation.open"}, input, connection) do
    required_scopes(%{id: "slack.conversation.open"}, input, connection)
  end

  def required_scopes(%{id: "slack.conversation.members"}, input, _connection) do
    input
    |> requested_conversation_type()
    |> conversation_read_scope()
    |> List.wrap()
  end

  def required_scopes(%{action_id: "slack.conversation.members"}, input, connection) do
    required_scopes(%{id: "slack.conversation.members"}, input, connection)
  end

  def required_scopes(%{id: "slack.thread.replies"}, input, _connection) do
    input
    |> requested_conversation_type()
    |> then(&Map.get(@conversation_history_scopes, &1, "channels:history"))
    |> List.wrap()
  end

  def required_scopes(%{action_id: "slack.thread.replies"}, input, connection) do
    required_scopes(%{id: "slack.thread.replies"}, input, connection)
  end

  def required_scopes(%{id: "slack.message.unread.list"}, input, _connection) do
    if Map.get(input, :channel, Map.get(input, "channel")) do
      type = requested_conversation_type(input)

      [
        conversation_read_scope(type),
        Map.get(@conversation_history_scopes, type, "channels:history")
      ]
    else
      Map.values(@conversation_type_scopes) ++ Map.values(@conversation_history_scopes)
    end
    |> Enum.uniq()
    |> Enum.sort()
  end

  def required_scopes(%{action_id: "slack.message.unread.list"}, input, connection) do
    required_scopes(%{id: "slack.message.unread.list"}, input, connection)
  end

  def required_scopes(%{id: "slack.conversation.mark_read"}, input, _connection) do
    input
    |> requested_conversation_type()
    |> then(&Map.get(@conversation_mark_scopes, &1, "channels:write"))
    |> List.wrap()
  end

  def required_scopes(%{action_id: "slack.conversation.mark_read"}, input, connection) do
    required_scopes(%{id: "slack.conversation.mark_read"}, input, connection)
  end

  def required_scopes(operation, _input, _connection), do: Map.get(operation, :scopes, [])

  defp requested_types(input) do
    input
    |> Map.get(:types, Map.get(input, "types", "public_channel"))
    |> to_string()
    |> String.split(",", trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> case do
      [] -> ["public_channel"]
      types -> types
    end
  end

  # A G ID is checked as a private channel, also when it belongs to a legacy
  # group DM, and a D ID as a DM. Any other ID, such as a C ID, is a public
  # channel unless a private channel or group DM is supplied; Slack never
  # gives a DM a C ID.
  defp requested_conversation_type(input) do
    supplied = supplied_conversation_type(input)

    case Map.get(input, :channel, Map.get(input, "channel")) do
      "G" <> _rest -> "private_channel"
      "D" <> _rest -> "im"
      nil -> supplied || "public_channel"
      _channel when supplied in ["private_channel", "mpim"] -> supplied
      _channel -> "public_channel"
    end
  end

  defp supplied_conversation_type(input) do
    case Map.get(input, :conversation_type, Map.get(input, "conversation_type")) do
      nil -> nil
      type -> type |> to_string() |> String.trim()
    end
  end

  defp conversation_read_scope(type) do
    Map.get(@conversation_type_scopes, type, "channels:read")
  end

  defp private_channel?(input) do
    Map.get(input, :is_private, Map.get(input, "is_private", false)) == true
  end

  # Slack resumes `channel` when it is given, also next to `users`. A G ID is
  # a group DM and a D ID a DM; for a C ID or no channel, several users mean a
  # group DM, and one user without a channel a DM.
  defp requested_open_conversation_type(input) do
    users = user_count(Map.get(input, :users, Map.get(input, "users")))

    case Map.get(input, :channel, Map.get(input, "channel")) do
      "G" <> _rest -> "mpim"
      "D" <> _rest -> "im"
      nil when users == 1 -> "im"
      _c_id_or_none when users > 1 -> "mpim"
      _c_id_or_none -> if supplied_conversation_type(input) == "mpim", do: "mpim", else: "im"
    end
  end

  # The client joins `users` with commas, so one entry can name several users.
  defp user_count(users) when is_binary(users), do: user_count([users])

  defp user_count(users) when is_list(users) do
    length(for user <- users, is_binary(user), id <- String.split(user, ",", trim: true), do: id)
  end

  defp user_count(_users), do: 0

  defp conversation_write_scope(type) do
    Map.get(@conversation_write_scopes, type, "im:write")
  end
end
