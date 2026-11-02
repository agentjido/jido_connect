defmodule Jido.Connect.Slack.ConversationHistoryTest do
  use ExUnit.Case, async: false

  alias Jido.Connect
  alias Jido.Connect.Slack.{Message, ScopeResolver}
  alias Jido.Connect.TestSupport.LiveSmoke

  @action_id "slack.conversation.history"
  @channel "C0CEEB41FU0"

  @history_scopes %{
    "public_channel" => "channels:history",
    "private_channel" => "groups:history",
    "im" => "im:history",
    "mpim" => "mpim:history"
  }

  setup {Req.Test, :verify_on_exit!}

  setup do
    Application.put_env(:jido_connect_slack, :slack_req_options, plug: {Req.Test, __MODULE__})
    on_exit(fn -> Application.delete_env(:jido_connect_slack, :slack_req_options) end)

    test_pid = self()

    stub_fixture = fn name ->
      Req.Test.stub(__MODULE__, fn conn ->
        send(test_pid, {:slack_request, URI.decode_query(conn.query_string)})
        Req.Test.json(conn, LiveSmoke.fixture!(:slack, name))
      end)
    end

    stub_fixture.("conversation_history_empty")
    %{stub_fixture: stub_fixture}
  end

  test "is a read action on message content for the bot and the user profile" do
    assert {:ok, action} = Connect.action(Jido.Connect.Slack, @action_id)

    assert %{
             resource: :conversation,
             verb: :read,
             data_classification: :message_content,
             policies: [:workspace_access],
             scopes: ["channels:history"],
             scope_resolver: ScopeResolver,
             auth_profile: :bot,
             auth_profiles: [:bot, :user],
             mutation?: false,
             risk: :read,
             confirmation: :none
           } = action
  end

  test "a page comes back as plain message maps with cursors and flags", %{
    stub_fixture: stub_fixture
  } do
    stub_fixture.("conversation_history_pages")

    assert {:ok, page} =
             Connect.invoke(
               Jido.Connect.Slack,
               @action_id,
               %{channel: @channel, conversation_type: "public_channel", limit: 7},
               runtime(:bot, ["channels:history"])
             )

    assert_received {:slack_request, %{"channel" => @channel, "limit" => "7"} = query}
    refute Map.has_key?(query, "conversation_type")
    refute_received {:slack_request, _query}

    assert page.has_more == true
    assert page.next_cursor != ""
    refute Map.has_key?(page, :is_limited)
    assert length(page.messages) == 7

    fields = Message.__struct__() |> Map.from_struct() |> Map.keys() |> Enum.sort()

    for message <- page.messages do
      refute is_struct(message)
      assert message |> Map.keys() |> Enum.sort() == fields
      assert %{channel: @channel, conversation_type: "public_channel"} = message
    end
  end

  test "an empty text stays an empty string in the action output", %{stub_fixture: stub_fixture} do
    stub_fixture.("conversation_history_attachments")
    context = context(:user, ["channels:history"])

    assert {:ok, %{messages: [%{text: "", blocks: nil, attachments: [_attachment]}]}} =
             Jido.Connect.Slack.Actions.GetConversationHistory.run(
               %{channel: @channel, conversation_type: "public_channel"},
               %{integration_context: context, credential_lease: lease(context)}
             )
  end

  test "defaults send inclusive false and limit 100" do
    assert {:ok, %{messages: [], has_more: false, next_cursor: ""}} =
             Connect.invoke(
               Jido.Connect.Slack,
               @action_id,
               %{channel: @channel, conversation_type: "public_channel"},
               runtime(:bot, ["channels:history"])
             )

    assert_received {:slack_request,
                     %{"channel" => @channel, "inclusive" => "false", "limit" => "100"} = query}

    assert map_size(query) == 3
  end

  test "invalid input fails validation without a request" do
    for input <- [
          %{conversation_type: "public_channel"},
          %{channel: @channel},
          %{channel: @channel, conversation_type: "group"},
          %{channel: @channel, conversation_type: "public_channel", limit: 0},
          %{channel: @channel, conversation_type: "public_channel", limit: 101}
        ] do
      assert {:error, %Connect.Error.ValidationError{reason: :input}} =
               Connect.invoke(
                 Jido.Connect.Slack,
                 @action_id,
                 input,
                 runtime(:bot, Map.values(@history_scopes))
               )
    end

    refute_received {:slack_request, _query}
  end

  test "each conversation type needs only its history scope, with either profile" do
    for profile <- [:bot, :user], {type, scope} <- @history_scopes do
      input = %{channel: @channel, conversation_type: type}

      assert {:ok, %{messages: []}} =
               Connect.invoke(Jido.Connect.Slack, @action_id, input, runtime(profile, [scope]))

      assert_received {:slack_request, _query}

      other_scopes = Map.values(@history_scopes) -- [scope]

      assert {:error, %Connect.Error.AuthError{reason: :missing_scopes, missing_scopes: [^scope]}} =
               Connect.invoke(
                 Jido.Connect.Slack,
                 @action_id,
                 input,
                 runtime(profile, other_scopes)
               )

      refute_received {:slack_request, _query}
    end
  end

  test "the scope resolver maps the declared type in both operation-ID forms" do
    for {type, scope} <- @history_scopes, key <- [:id, :action_id] do
      assert ScopeResolver.required_scopes(%{key => @action_id}, %{conversation_type: type}, nil) ==
               [scope]

      assert ScopeResolver.required_scopes(
               %{key => @action_id},
               %{"conversation_type" => type},
               nil
             ) == [scope]
    end

    # The declared type decides, not the channel prefix: Slack gives private
    # channels and group DMs C IDs, and G IDs can be either.
    assert ScopeResolver.required_scopes(
             %{id: @action_id},
             %{channel: "C0CDELYPYKF", conversation_type: "mpim"},
             nil
           ) == ["mpim:history"]

    assert ScopeResolver.required_scopes(
             %{id: @action_id},
             %{channel: "G123", conversation_type: "mpim"},
             nil
           ) == ["mpim:history"]

    # Availability checks run without input: without a connection, the static
    # scope applies.
    assert ScopeResolver.required_scopes(%{id: @action_id}, %{}, nil) == ["channels:history"]
  end

  test "the tool is offered to a connection with any one history scope" do
    for profile <- [:bot, :user], {_type, scope} <- @history_scopes do
      assert %{state: :available, missing_scopes: []} =
               history_availability(context(profile, [scope]).connection)
    end

    assert %{state: :missing_scopes, missing_scopes: ["channels:history"]} =
             history_availability(context(:bot, ["channels:read"]).connection)
  end

  test "policy denial and an expired lease make no provider call" do
    input = %{channel: @channel, conversation_type: "public_channel"}
    opts = runtime(:bot, ["channels:history"])

    assert {:error, %Connect.Error.AuthError{reason: :policy_denied}} =
             Connect.invoke(
               Jido.Connect.Slack,
               @action_id,
               input,
               Keyword.put(opts, :policy, fn _operation, _input, _context, _connection ->
                 :deny
               end)
             )

    context = Keyword.fetch!(opts, :context)

    expired =
      lease(context)
      |> Map.put(:expires_at, DateTime.add(DateTime.utc_now(), -60, :second))

    assert {:error, %Connect.Error.AuthError{}} =
             Connect.invoke(Jido.Connect.Slack, @action_id, input,
               context: context,
               credential_lease: expired
             )

    refute_received {:slack_request, _query}
  end

  defp history_availability(connection) do
    %{connection: connection}
    |> Jido.Connect.Slack.Plugin.tool_availability()
    |> Enum.find(&(&1.tool == @action_id))
  end

  defp runtime(profile, scopes) do
    context = context(profile, scopes)
    [context: context, credential_lease: lease(context)]
  end

  defp context(profile, scopes) do
    connection =
      Connect.Connection.new!(%{
        id: "slack-#{profile}",
        provider: :slack,
        profile: profile,
        tenant_id: "tenant-1",
        owner_type: if(profile == :user, do: :user, else: :tenant),
        owner_id: "owner-1",
        status: :connected,
        scopes: scopes
      })

    Connect.Context.new!(%{
      tenant_id: "tenant-1",
      actor: %{id: "user-1", type: :user},
      connection: connection
    })
  end

  defp lease(context) do
    Connect.CredentialLease.new!(%{
      connection_id: context.connection.id,
      expires_at: DateTime.add(DateTime.utc_now(), 300, :second),
      scopes: context.connection.scopes,
      fields: %{access_token: "token"}
    })
  end
end
