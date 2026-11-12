defmodule Jido.Connect.Slack.DeliveryTest do
  use ExUnit.Case, async: false

  alias Jido.Connect
  alias Jido.Connect.TestSupport.LiveSmoke

  # Client modules that report their use and pass the call on to the package
  # client, so the response still comes from the recording.
  defmodule ContextClient do
    def open_conversation(params, token) do
      send(self(), {:client, __MODULE__})
      Jido.Connect.Slack.Client.open_conversation(params, token)
    end
  end

  defmodule LeaseClient do
    def open_conversation(params, token) do
      send(self(), {:client, __MODULE__})
      Jido.Connect.Slack.Client.open_conversation(params, token)
    end
  end

  # Recorded from the test workspace with the bot token.
  @authorizing_user "U0CDPFT1RDJ"
  @second_user "U0CDEL6734M"
  @dm "D0CD4G48UFR"
  @mpim "C0CDELYPYKF"
  @channel "C0CEEB41FU0"
  @thread_ts "1793371034.447499"
  @link "https://example.com/jido-connect/delivery-check"

  setup do
    Application.put_env(:jido_connect_slack, :slack_req_options, plug: {Req.Test, __MODULE__})
    on_exit(fn -> Application.delete_env(:jido_connect_slack, :slack_req_options) end)
  end

  describe "slack.conversation.open" do
    test "a lease without slack_client reaches conversations.open with the supplied user" do
      stub_fixture("conversations_open_im")

      assert {:ok, %{channel: @dm, conversation: %{id: @dm}}} =
               Connect.invoke(
                 Jido.Connect.Slack,
                 "slack.conversation.open",
                 %{users: [@authorizing_user]},
                 runtime(["im:write"])
               )

      assert_received {:slack_request, "POST", "/api/conversations.open", body}

      assert body == %{
               "users" => @authorizing_user,
               "return_im" => false,
               "prevent_creation" => false
             }
    end

    test "a context provider_client goes before the lease's slack_client" do
      input = %{users: [@authorizing_user]}

      stub_fixture("conversations_open_im")

      assert {:ok, %{channel: @dm}} =
               Connect.invoke(
                 Jido.Connect.Slack,
                 "slack.conversation.open",
                 input,
                 runtime(["im:write"], %{slack_client: LeaseClient}) ++
                   [provider_client: ContextClient]
               )

      assert_received {:client, ContextClient}
      refute_received {:client, LeaseClient}

      stub_fixture("conversations_open_im")

      assert {:ok, %{channel: @dm}} =
               Connect.invoke(
                 Jido.Connect.Slack,
                 "slack.conversation.open",
                 input,
                 runtime(["im:write"], %{slack_client: LeaseClient})
               )

      assert_received {:client, LeaseClient}
      refute_received {:client, ContextClient}
    end

    test "one user needs im:write and opens the DM" do
      input = %{users: [@authorizing_user]}

      assert {:error,
              %Connect.Error.AuthError{reason: :missing_scopes, missing_scopes: ["im:write"]}} =
               Connect.invoke(
                 Jido.Connect.Slack,
                 "slack.conversation.open",
                 input,
                 runtime(["mpim:write"])
               )

      refute_received {:slack_request, _method, _path, _body}

      stub_fixture("conversations_open_im")

      assert {:ok, %{channel: @dm}} =
               Connect.invoke(
                 Jido.Connect.Slack,
                 "slack.conversation.open",
                 input,
                 runtime(["im:write"])
               )

      assert_received {:slack_request, "POST", "/api/conversations.open",
                       %{"users" => @authorizing_user}}
    end

    test "two users need mpim:write and open the group DM with both IDs" do
      input = %{users: [@authorizing_user, @second_user]}

      assert {:error,
              %Connect.Error.AuthError{reason: :missing_scopes, missing_scopes: ["mpim:write"]}} =
               Connect.invoke(
                 Jido.Connect.Slack,
                 "slack.conversation.open",
                 input,
                 runtime(["im:write"])
               )

      refute_received {:slack_request, _method, _path, _body}

      stub_fixture("conversations_open_mpim")

      assert {:ok, %{channel: @mpim, conversation: %{id: @mpim, is_mpim: true, is_im: false}}} =
               Connect.invoke(
                 Jido.Connect.Slack,
                 "slack.conversation.open",
                 input,
                 runtime(["mpim:write"])
               )

      assert_received {:slack_request, "POST", "/api/conversations.open", body}

      assert body == %{
               "users" => "#{@authorizing_user},#{@second_user}",
               "return_im" => false,
               "prevent_creation" => false
             }
    end

    # Slack's answer to resuming by channel was not recorded; the recording of
    # opening the same group DM by its users stands in for it, since the test
    # checks the scope and the request.
    test "a group DM resumed by its C ID with conversation_type mpim needs mpim:write, not im:write" do
      input = %{channel: @mpim, conversation_type: "mpim"}

      assert {:error,
              %Connect.Error.AuthError{reason: :missing_scopes, missing_scopes: ["mpim:write"]}} =
               Connect.invoke(
                 Jido.Connect.Slack,
                 "slack.conversation.open",
                 input,
                 runtime(["im:write"])
               )

      refute_received {:slack_request, _method, _path, _body}

      stub_fixture("conversations_open_mpim")

      assert {:ok, %{channel: @mpim}} =
               Connect.invoke(
                 Jido.Connect.Slack,
                 "slack.conversation.open",
                 input,
                 runtime(["mpim:write"])
               )

      assert_received {:slack_request, "POST", "/api/conversations.open", body}

      assert body == %{
               "channel" => @mpim,
               "return_im" => false,
               "prevent_creation" => false
             }
    end

    # Several users or a G ID mean a group DM, one user or a D ID a DM,
    # whatever type the caller declares.
    test "conversation_type does not change the scope that the users or the channel ID need" do
      cases = [
        {%{users: [@authorizing_user, @second_user], conversation_type: "im"}, "mpim:write"},
        {%{users: ["#{@authorizing_user},#{@second_user}"], conversation_type: "im"},
         "mpim:write"},
        {%{channel: "G0CDELYPYKF", conversation_type: "im"}, "mpim:write"},
        {%{channel: "G0CDELYPYKF"}, "mpim:write"},
        {%{users: [@authorizing_user], conversation_type: "im"}, "im:write"},
        {%{users: [@authorizing_user], conversation_type: "mpim"}, "im:write"},
        {%{channel: "", users: [@authorizing_user], conversation_type: "mpim"}, "im:write"},
        {%{channel: @dm, conversation_type: "mpim"}, "im:write"},
        {%{channel: @mpim}, "im:write"}
      ]

      for {input, scope} <- cases do
        assert {:error,
                %Connect.Error.AuthError{reason: :missing_scopes, missing_scopes: missing}} =
                 Connect.invoke(Jido.Connect.Slack, "slack.conversation.open", input, runtime([]))

        assert {input, missing} == {input, [scope]}
      end

      refute_received {:slack_request, _method, _path, _body}
    end

    test "conversation_type takes only im or mpim" do
      assert {:error,
              %Connect.Error.ValidationError{
                reason: :input,
                details: %{errors: [%Zoi.Error{code: :not_in_values, path: [:conversation_type]}]}
              }} =
               Connect.invoke(
                 Jido.Connect.Slack,
                 "slack.conversation.open",
                 %{channel: @mpim, conversation_type: "private_channel"},
                 runtime(["im:write", "mpim:write"])
               )

      refute_received {:slack_request, _method, _path, _body}
    end
  end

  describe "slack.message.post" do
    test "a thread reply sends the exact text with its link, a string thread_ts and reply_broadcast false" do
      %{"ts" => ts, "message" => %{"text" => text} = message} =
        LiveSmoke.fixture!(:slack, "chat_post_message_thread_reply")

      assert byte_size(text) > 512
      assert text =~ "<#{@link}|open the delivery check>"

      stub_fixture("chat_post_message_thread_reply")

      assert {:ok, output} =
               Connect.invoke(
                 Jido.Connect.Slack,
                 "slack.message.post",
                 %{channel: @channel, text: text, thread_ts: @thread_ts},
                 runtime(["chat:write"])
               )

      assert_received {:slack_request, "POST", "/api/chat.postMessage", body}

      assert body == %{
               "channel" => @channel,
               "text" => text,
               "thread_ts" => @thread_ts,
               "reply_broadcast" => false
             }

      assert output == %{channel: @channel, ts: ts, message: message}
      assert %{"thread_ts" => @thread_ts} = message
      refute Map.has_key?(message, "subtype")
    end

    test "a text-only post sends reply_broadcast false and no thread_ts" do
      %{"ts" => ts, "message" => %{"text" => text} = message} =
        LiveSmoke.fixture!(:slack, "chat_post_message_channel")

      stub_fixture("chat_post_message_channel")

      assert {:ok, output} =
               Connect.invoke(
                 Jido.Connect.Slack,
                 "slack.message.post",
                 %{channel: @channel, text: text},
                 runtime(["chat:write"])
               )

      assert_received {:slack_request, "POST", "/api/chat.postMessage", body}
      assert body == %{"channel" => @channel, "text" => text, "reply_broadcast" => false}
      assert output == %{channel: @channel, ts: ts, message: message}
    end

    # The README promises that such a success stays a success, so a host that
    # retries on errors does not post twice. Slack has not been seen to answer
    # like this: the body is the recorded channel post without its top-level
    # channel and ts.
    test "a success without channel and ts stays a success without them" do
      %{"message" => %{"text" => text} = message} =
        recorded = LiveSmoke.fixture!(:slack, "chat_post_message_channel")

      stub_response(&Req.Test.json(&1, Map.drop(recorded, ["channel", "ts"])))

      assert {:ok, output} =
               Connect.invoke(
                 Jido.Connect.Slack,
                 "slack.message.post",
                 %{channel: @channel, text: text},
                 runtime(["chat:write"])
               )

      assert output == %{message: message}
      assert_one_request()
    end

    test "posting needs chat:write and no history or conversation-open scope" do
      other_scopes = [
        "channels:history",
        "groups:history",
        "im:history",
        "mpim:history",
        "im:write",
        "mpim:write"
      ]

      %{"message" => %{"text" => text}} = LiveSmoke.fixture!(:slack, "chat_post_message_channel")
      input = %{channel: @channel, text: text}

      assert {:error,
              %Connect.Error.AuthError{reason: :missing_scopes, missing_scopes: ["chat:write"]}} =
               Connect.invoke(
                 Jido.Connect.Slack,
                 "slack.message.post",
                 input,
                 runtime(other_scopes)
               )

      refute_received {:slack_request, _method, _path, _body}
    end
  end

  describe "failures" do
    # The ok:false bodies are recorded. HTTP and transport failures are not:
    # Slack cannot be made to answer 503 or drop a connection on purpose, so
    # their status, text body and transport reason come from Req.Test.
    test "slack.message.post keeps ok:false, HTTP and transport failures apart and sends each once" do
      assert_failures(
        "slack.message.post",
        %{channel: "C0CDDP1JEAX", text: "Hello"},
        ["chat:write"],
        {"chat_post_message_not_in_channel", "not_in_channel"}
      )
    end

    test "slack.conversation.open keeps ok:false, HTTP and transport failures apart and sends each once" do
      assert_failures(
        "slack.conversation.open",
        %{users: ["U0000000000"]},
        ["im:write"],
        {"conversations_open_user_not_found", "user_not_found"}
      )
    end
  end

  test "both actions stay workspace-policy writes that AI callers confirm" do
    assert {:ok,
            %{
              mutation?: true,
              risk: :write,
              confirmation: :required_for_ai,
              provider_idempotency?: false,
              policies: [:workspace_access],
              scopes: ["chat:write"],
              auth_profiles: [:bot, :user]
            }} = Connect.action(Jido.Connect.Slack, "slack.message.post")

    assert {:ok,
            %{
              mutation?: true,
              risk: :write,
              confirmation: :required_for_ai,
              provider_idempotency?: false,
              policies: [:workspace_access],
              scopes: ["im:write"],
              scope_resolver: Jido.Connect.Slack.ScopeResolver,
              auth_profiles: [:bot]
            }} = Connect.action(Jido.Connect.Slack, "slack.conversation.open")
  end

  defp assert_failures(action_id, input, scopes, {fixture, slack_error}) do
    invoke = fn -> Connect.invoke(Jido.Connect.Slack, action_id, input, runtime(scopes)) end

    stub_fixture(fixture)

    assert {:error,
            %Connect.Error.ProviderError{
              provider: :slack,
              status: 200,
              reason: ^slack_error,
              delivery: :response_received,
              mutation?: true
            }} = invoke.()

    assert_one_request()

    stub_response(fn conn ->
      conn |> Plug.Conn.put_status(503) |> Req.Test.text("Service Unavailable")
    end)

    assert {:error,
            %Connect.Error.ProviderError{
              provider: :slack,
              status: 503,
              reason: :http_error,
              delivery: :rejected,
              mutation?: true
            }} = invoke.()

    assert_one_request()

    stub_response(&Req.Test.transport_error(&1, :timeout))

    assert {:error,
            %Connect.Error.ProviderError{
              provider: :slack,
              status: nil,
              reason: :request_error,
              delivery: :sent_outcome_unknown,
              mutation?: true
            }} = invoke.()

    assert_one_request()
  end

  defp assert_one_request do
    assert_received {:slack_request, "POST", _path, _body}
    refute_received {:slack_request, _method, _path, _body}
  end

  defp stub_fixture(name),
    do: stub_response(&Req.Test.json(&1, LiveSmoke.fixture!(:slack, name)))

  # Reports every request to the test process, so a second request, such as
  # a retry, shows up as a second message.
  defp stub_response(respond) do
    test_pid = self()

    Req.Test.stub(__MODULE__, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      send(test_pid, {:slack_request, conn.method, conn.request_path, Jason.decode!(body)})
      respond.(conn)
    end)
  end

  defp runtime(scopes, fields \\ %{}) do
    connection =
      Connect.Connection.new!(%{
        id: "slack-bot",
        provider: :slack,
        profile: :bot,
        tenant_id: "tenant-1",
        owner_type: :tenant,
        owner_id: "T0CEE692400",
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
        fields: Map.put(fields, :access_token, "token")
      })

    [context: context, credential_lease: lease]
  end
end
