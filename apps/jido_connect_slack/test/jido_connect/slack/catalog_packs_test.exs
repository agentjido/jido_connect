defmodule Jido.Connect.Slack.CatalogPacksTest do
  use ExUnit.Case, async: true

  alias Jido.Connect
  alias Jido.Connect.Slack.CatalogPacks

  defmodule FakeClient do
    def auth_test("token") do
      record(:auth_test)
      {:ok, %{team_id: "T123", user_id: "U123", team: "Demo", user: "demo-user"}}
    end

    def list_unread_messages(%{limit: 20}, "token") do
      record(:list_unread_messages)

      {:ok,
       %{
         messages: [%{channel_id: "C123", ts: "1700000001.000100", text: "Unread"}],
         conversations: [%{id: "C123", name: "general", type: "public_channel"}],
         count: 1,
         truncated: false,
         coverage: %{complete: true}
       }}
    end

    def get_presence("token") do
      record(:get_presence)

      {:ok,
       %{
         availability: %{state: "away", manual_away: true},
         status: %{text: "Meeting", emoji: ":calendar:", expires_at: nil}
       }}
    end

    def list_emoji("token") do
      record(:list_emoji)
      {:ok, %{emoji: [%{name: "shipit", code: ":shipit:", type: "alias"}]}}
    end

    def mark_conversation_read(%{channel: "C123", ts: "1700000001.000100"}, "token") do
      record(:mark_conversation_read)
      {:ok, %{channel: "C123", ts: "1700000001.000100"}}
    end

    def set_status(_attrs, "token") do
      record(:set_status)
      {:ok, %{status: %{text: "Meeting", emoji: ":calendar:", expires_at: nil}}}
    end

    def calls, do: Process.get({__MODULE__, :calls}, []) |> Enum.reverse()
    def reset, do: Process.put({__MODULE__, :calls}, [])

    defp record(call),
      do: Process.put({__MODULE__, :calls}, [call | Process.get({__MODULE__, :calls}, [])])
  end

  setup do
    FakeClient.reset()
    :ok
  end

  test "reviewed packs expose only the nine accepted canonical Slack actions" do
    reader = CatalogPacks.reader()
    editor = CatalogPacks.editor()

    assert reader.id == :slack_messages_reader
    assert editor.id == :slack_messages_editor

    assert reader.allowed_tools == [
             "slack.message.unread.list",
             "slack.thread.replies",
             "slack.presence.get",
             "slack.emoji.list"
           ]

    assert editor.allowed_tools ==
             reader.allowed_tools ++
               [
                 "slack.message.post",
                 "slack.conversation.mark_read",
                 "slack.presence.set",
                 "slack.profile.status.set",
                 "slack.profile.status.clear"
               ]

    Enum.each(editor.allowed_tools, fn id ->
      assert {:ok, action} = Connect.action(Jido.Connect.Slack, id)

      if action.mutation? do
        assert action.confirmation == :required_for_ai
        refute id in reader.allowed_tools
      else
        assert action.confirmation == :none
        assert id in reader.allowed_tools
      end
    end)

    for id <- ["slack.message.post", "slack.thread.replies"] do
      assert {:ok, %{auth_profile: :bot, auth_profiles: [:bot, :user]}} =
               Connect.action(Jido.Connect.Slack, id)
    end

    assert {:ok, %{auth_profile: :bot, auth_profiles: [:bot, :user]}} =
             Connect.action(Jido.Connect.Slack, "slack.auth.test")
  end

  test "read actions use an injected client without adding it to credential fields" do
    opts = runtime_opts()

    assert {:ok, %{count: 1, messages: [%{text: "Unread"}]}} =
             Connect.invoke(Jido.Connect.Slack, "slack.message.unread.list", %{}, opts)

    assert {:ok, %{availability: %{state: "away"}, status: %{text: "Meeting"}}} =
             Connect.invoke(Jido.Connect.Slack, "slack.presence.get", %{}, opts)

    assert {:ok, %{count: 1, emoji: [%{name: "shipit"}]}} =
             Connect.invoke(Jido.Connect.Slack, "slack.emoji.list", %{}, opts)

    assert FakeClient.calls() == [:list_unread_messages, :get_presence, :list_emoji]
  end

  test "auth test accepts the imported user profile and the injected provider client" do
    assert {:ok, %{team_id: "T123", user_id: "U123"}} =
             Connect.invoke(Jido.Connect.Slack, "slack.auth.test", %{}, runtime_opts())

    assert FakeClient.calls() == [:auth_test]
  end

  test "write preparation has no provider effect and commit calls once" do
    input = %{channel: "C123", ts: "1700000001.000100"}
    opts = runtime_opts()

    assert {:ok, prepared} =
             Connect.prepare(Jido.Connect.Slack, "slack.conversation.mark_read", input, opts)

    assert FakeClient.calls() == []
    assert prepared.preview.action_id == "slack.conversation.mark_read"

    assert {:ok, %{marked: true, channel: "C123", ts: "1700000001.000100"}} =
             Connect.commit(
               Jido.Connect.Slack,
               prepared,
               input,
               commit_opts(opts, prepared)
             )

    assert FakeClient.calls() == [:mark_conversation_read]
  end

  test "scope denial and invalid input stop before the provider client" do
    {context, lease} = context_and_lease()
    context = %{context | connection: %{context.connection | scopes: ["channels:read"]}}

    assert {:error, %Connect.Error.AuthError{reason: :missing_scopes}} =
             Connect.invoke(
               Jido.Connect.Slack,
               "slack.message.unread.list",
               %{},
               context: context,
               credential_lease: lease,
               provider_client: FakeClient
             )

    assert {:error, %Connect.Error.ValidationError{}} =
             Connect.prepare(
               Jido.Connect.Slack,
               "slack.presence.set",
               %{mode: "active"},
               runtime_opts()
             )

    assert FakeClient.calls() == []
  end

  test "invalid status date is rejected before a provider write" do
    input = %{text: "Meeting", emoji: ":calendar:", expires_at: "tomorrow"}
    opts = runtime_opts()

    assert {:ok, prepared} =
             Connect.prepare(Jido.Connect.Slack, "slack.profile.status.set", input, opts)

    assert {:error, %Connect.Error.ValidationError{reason: :invalid_status}} =
             Connect.commit(
               Jido.Connect.Slack,
               prepared,
               input,
               commit_opts(opts, prepared)
             )

    assert FakeClient.calls() == []
  end

  defp runtime_opts do
    {context, lease} = context_and_lease()

    [
      context: context,
      credential_lease: lease,
      provider_client: FakeClient,
      binding_ref: "binding-slack"
    ]
  end

  defp commit_opts(opts, prepared) do
    opts ++
      [
        execution_authorization: %{plan_id: prepared.id},
        authorization_validator: fn evidence, current, _context ->
          evidence.plan_id == current.id
        end
      ]
  end

  defp context_and_lease do
    scopes = [
      "channels:history",
      "channels:read",
      "channels:write",
      "chat:write",
      "emoji:read",
      "groups:history",
      "groups:read",
      "groups:write",
      "im:history",
      "im:read",
      "im:write",
      "mpim:history",
      "mpim:read",
      "mpim:write",
      "users:read",
      "users.profile:read",
      "users.profile:write",
      "users:write"
    ]

    connection =
      Connect.Connection.new!(%{
        id: "slack-user-T123-U123",
        provider: :slack,
        profile: :user,
        tenant_id: "tenant-1",
        owner_type: :user,
        owner_id: "user-1",
        status: :connected,
        scopes: scopes
      })

    context =
      Connect.Context.new!(%{
        tenant_id: "tenant-1",
        actor: %{id: "user-1", type: :user},
        connection: connection
      })

    lease =
      Connect.CredentialLease.new!(%{
        connection_id: connection.id,
        expires_at: DateTime.add(DateTime.utc_now(), 300, :second),
        scopes: scopes,
        fields: %{access_token: "token"}
      })

    {context, lease}
  end
end
