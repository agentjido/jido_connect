defmodule Jido.Connect.Slack.ScopeResolver do
  @moduledoc """
  Resolves Slack scopes whose requirements depend on action input.

  Slack's conversations endpoints change required scopes based on the requested
  conversation types, so the static DSL scopes represent the default public
  channel case and this resolver tightens checks for private channels, DMs, and
  multi-person DMs. Slack history reads use the same conversation distinctions.
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

  defp requested_conversation_type(input) do
    case Map.get(input, :conversation_type, Map.get(input, "conversation_type")) do
      nil -> type_from_channel(Map.get(input, :channel, Map.get(input, "channel")))
      type -> type |> to_string() |> String.trim()
    end
  end

  defp conversation_read_scope(type) do
    Map.get(@conversation_type_scopes, type, "channels:read")
  end

  defp private_channel?(input) do
    Map.get(input, :is_private, Map.get(input, "is_private", false)) == true
  end

  defp requested_open_conversation_type(input) do
    case Map.get(input, :conversation_type, Map.get(input, "conversation_type")) do
      nil -> open_type_from_input(input)
      type -> type |> to_string() |> String.trim()
    end
  end

  defp open_type_from_input(input) do
    users = Map.get(input, :users, Map.get(input, "users"))
    channel = Map.get(input, :channel, Map.get(input, "channel"))

    cond do
      user_count(users) > 1 -> "mpim"
      match?("G" <> _rest, channel) -> "mpim"
      true -> "im"
    end
  end

  defp user_count(users) when is_list(users), do: length(users)

  defp user_count(users) when is_binary(users) do
    users
    |> String.split(",", trim: true)
    |> length()
  end

  defp user_count(_users), do: 0

  defp conversation_write_scope(type) do
    Map.get(@conversation_write_scopes, type, "im:write")
  end

  defp type_from_channel("C" <> _rest), do: "public_channel"
  defp type_from_channel("G" <> _rest), do: "private_channel"
  defp type_from_channel("D" <> _rest), do: "im"
  defp type_from_channel(_channel), do: "public_channel"
end
