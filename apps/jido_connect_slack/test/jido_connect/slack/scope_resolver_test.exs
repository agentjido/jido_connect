defmodule Jido.Connect.Slack.ScopeResolverTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Slack.ScopeResolver

  # Slack's scope for each conversation type, per kind of access.
  @read %{
    "public_channel" => "channels:read",
    "private_channel" => "groups:read",
    "im" => "im:read",
    "mpim" => "mpim:read"
  }

  @manage %{
    "public_channel" => "channels:manage",
    "private_channel" => "groups:write",
    "im" => "im:write",
    "mpim" => "mpim:write"
  }

  @history %{
    "public_channel" => "channels:history",
    "private_channel" => "groups:history",
    "im" => "im:history",
    "mpim" => "mpim:history"
  }

  @mark %{
    "public_channel" => "channels:write",
    "private_channel" => "groups:write",
    "im" => "im:write",
    "mpim" => "mpim:write"
  }

  @channel_actions %{
    "slack.conversation.info" => @read,
    "slack.conversation.members" => @read,
    "slack.channel.archive" => @manage,
    "slack.channel.unarchive" => @manage,
    "slack.channel.rename" => @manage,
    "slack.conversation.invite" => @manage,
    "slack.conversation.kick" => @manage,
    "slack.thread.replies" => @history,
    "slack.conversation.history" => @history,
    "slack.conversation.mark_read" => @mark
  }

  @unread "slack.message.unread.list"

  @types [nil, "public_channel", "private_channel", "im", "mpim"]

  # Slack gives C IDs to public channels, private channels and group DMs,
  # never to DMs. IDs with another prefix are checked the same way.
  @c_id_types %{
    nil => "public_channel",
    "public_channel" => "public_channel",
    "private_channel" => "private_channel",
    "im" => "public_channel",
    "mpim" => "mpim"
  }

  @no_channel_types %{
    nil => "public_channel",
    "public_channel" => "public_channel",
    "private_channel" => "private_channel",
    "im" => "im",
    "mpim" => "mpim"
  }

  # The conversation type whose scope is checked, by channel ID and supplied
  # type. A G ID is a private channel and a D ID a DM. The client drops an
  # empty channel, so it counts as none.
  @checked_type %{
    "C0123" => @c_id_types,
    "Z0123" => @c_id_types,
    "G0123" => %{
      nil => "private_channel",
      "public_channel" => "private_channel",
      "private_channel" => "private_channel",
      "im" => "private_channel",
      "mpim" => "private_channel"
    },
    "D0123" => %{
      nil => "im",
      "public_channel" => "im",
      "private_channel" => "im",
      "im" => "im",
      "mpim" => "im"
    },
    "" => @no_channel_types,
    nil => @no_channel_types
  }

  describe "actions on one conversation" do
    test "check the type that the channel ID allows, whatever type is supplied" do
      for {action, scopes} <- @channel_actions,
          {channel, checked} <- @checked_type,
          type <- @types do
        input = input(channel, type)

        assert {action, input, ScopeResolver.required_scopes(%{id: action}, input, nil)} ==
                 {action, input, [scopes[checked[type]]]}
      end
    end

    test "slack.message.unread.list with a channel checks read and history of that type" do
      for {channel, checked} <- Map.drop(@checked_type, [nil, ""]), type <- @types do
        input = input(channel, type)
        expected = Enum.sort([@read[checked[type]], @history[checked[type]]])

        assert {input, ScopeResolver.required_scopes(%{id: @unread}, input, nil)} ==
                 {input, expected}
      end
    end

    test "slack.message.unread.list without a channel needs every read and history scope" do
      all = Enum.sort(Map.values(@read) ++ Map.values(@history))

      for channel <- [nil, ""], type <- @types do
        input = input(channel, type)
        assert {input, ScopeResolver.required_scopes(%{id: @unread}, input, nil)} == {input, all}
      end
    end

    test "no supplied type changes the scopes that a G or D channel ID requires" do
      for action <- [@unread | Map.keys(@channel_actions)],
          channel <- ["G0123", "D0123"],
          type <- @types do
        required = &ScopeResolver.required_scopes(%{id: action}, &1, nil)

        assert {action, type, required.(input(channel, type))} ==
                 {action, type, required.(input(channel, nil))}
      end
    end

    test "string keys and the action_id form resolve alike" do
      input = %{"channel" => "G0123", "conversation_type" => "public_channel"}

      for {action, scopes} <- @channel_actions do
        assert ScopeResolver.required_scopes(%{action_id: action}, input, nil) ==
                 [scopes["private_channel"]]
      end

      assert ScopeResolver.required_scopes(%{action_id: @unread}, input, nil) ==
               ["groups:history", "groups:read"]
    end
  end

  # Slack resumes `channel` when it is given, also next to `users`, and the
  # client joins `users` with commas.
  describe "slack.conversation.open" do
    test "several users or a G ID need mpim:write, one user or a D ID im:write, whatever type is supplied" do
      targets = [
        {%{users: ["U01", "U02"]}, "mpim:write"},
        {%{users: ["U01,U02"]}, "mpim:write"},
        {%{"users" => "U01,U02"}, "mpim:write"},
        {%{channel: "G0123"}, "mpim:write"},
        {%{channel: "G0123", users: ["U01"]}, "mpim:write"},
        {%{channel: "C0123", users: ["U01", "U02"]}, "mpim:write"},
        {%{channel: "", users: ["U01", "U02"]}, "mpim:write"},
        {%{users: ["U01"]}, "im:write"},
        {%{channel: "", users: ["U01"]}, "im:write"},
        {%{channel: "D0123"}, "im:write"},
        {%{channel: "D0123", users: ["U01", "U02"]}, "im:write"}
      ]

      for {target, scope} <- targets, type <- @types do
        input = put_type(target, type)
        assert {input, open_scopes(input)} == {input, [scope]}
      end
    end

    # Slack gives group DMs C IDs too, so only there the supplied type decides.
    test "for a C ID or no target, a supplied mpim selects mpim:write" do
      for target <- [%{channel: "C0123"}, %{channel: "C0123", users: ["U01"]}, %{}],
          type <- @types do
        input = put_type(target, type)
        scope = if type == "mpim", do: "mpim:write", else: "im:write"

        assert {input, open_scopes(input)} == {input, [scope]}
      end
    end
  end

  defp open_scopes(input) do
    ScopeResolver.required_scopes(%{id: "slack.conversation.open"}, input, nil)
  end

  defp put_type(input, nil), do: input
  defp put_type(input, type), do: Map.put(input, :conversation_type, type)

  defp input(channel, type) do
    %{channel: channel, conversation_type: type}
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end
end
