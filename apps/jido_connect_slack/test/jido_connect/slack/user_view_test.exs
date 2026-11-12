defmodule Jido.Connect.Slack.UserViewTest do
  # Not async: the action tests point the package's Req options at a stub.
  use ExUnit.Case, async: false

  alias Jido.Connect
  alias Jido.Connect.{Error, WebhookDelivery}
  alias Jido.Connect.Slack.{OAuth, Webhook}
  alias Jido.Connect.Slack.TestSupport.SyntheticFixture
  alias Jido.Connect.TestSupport.LiveSmoke

  import Jido.Connect.Slack.TestSupport.CapturedDelivery,
    only: [payload!: 1, replay: 1, derive: 2]

  # The user-view captures came from the test workspace on 2026-11-02 and
  # were sanitized by the user view live smoke test: a message in
  # #jc-live-no-bot (C0CDDP1JEAX), which the bot has left, a mention of the
  # app in a public channel without the bot, and a message in a DM of the
  # authorizing user without the bot. Their texts are placeholders. The
  # other captures are the bot-view deliveries of the message ingress test.

  @bot_user "U0CDHUEBVEJ"
  @authorizing_user "U0CDPFT1RDJ"
  @bot_dm "D0CD4G48UFR"

  describe "message signals" do
    test "a captured user event from a channel the bot is not in normalizes through the public channel trigger" do
      payload = payload!("message_public_user_view")

      assert {:ok,
              %WebhookDelivery{
                signature_state: :verified,
                event: "message",
                normalized_signal: delivered
              }} = replay("message_public_user_view")

      signal = Map.delete(delivered, :delivery)

      assert signal == %{
               team_id: "T0CEE692400",
               event_id: "Ev0CEZC2RHB2",
               channel: "C0CDDP1JEAX",
               channel_type: "channel",
               user: @authorizing_user,
               text: payload["event"]["text"],
               ts: "1793628631.312089",
               event_ts: "1793628631.312089",
               view: "user",
               viewer: @authorizing_user
             }

      assert {:ok, ^signal} = Webhook.normalize_signal("message.channels", payload)
      assert {:ok, ^signal} = Webhook.normalize_event(payload)
    end

    test "a mention of the app in a channel without the bot is a user-view message" do
      payload = payload!("message_mention_user_view")

      # The bot user that the app_mention capture names as its authorization.
      assert [%{"is_bot" => true, "user_id" => @bot_user}] =
               payload!("app_mention")["authorizations"]

      assert [
               %{
                 "elements" => [
                   %{"elements" => [%{"type" => "user", "user_id" => @bot_user} | _]}
                 ]
               }
             ] =
               payload["event"]["blocks"]

      assert {:ok, signal} = Webhook.normalize_signal("message.channels", payload)

      assert %{channel: "C0CEE6E6EU8", ts: "1793627810.026799", view: "user"} = signal
      assert signal.viewer == @authorizing_user
    end

    test "a DM without the bot arrives in the user view with sender and conversation" do
      assert {:ok, %WebhookDelivery{normalized_signal: delivered}} =
               replay("message_im_user_view")

      signal = Map.delete(delivered, :delivery)
      payload = payload!("message_im_user_view")
      assert {:ok, ^signal} = Webhook.normalize_signal("message.im", payload)

      assert %{
               channel: "D0CDPKW29DJ",
               channel_type: "im",
               user: @authorizing_user,
               sender: %{id: @authorizing_user},
               conversation: %{id: "D0CDPKW29DJ", type: "im"},
               view: "user",
               viewer: @authorizing_user
             } = signal

      refute Map.has_key?(signal, :shared_messages)
    end

    test "captured deliveries from conversations with the bot name the bot's view" do
      for {fixture, trigger} <- [
            {"message_public", "message.channels"},
            {"message_private", "message.groups"},
            {"message_im", "message.im"},
            {"message_mpim", "message.mpim"},
            {"message_thread_reply", "message.thread_reply"},
            {"message_file_share", "message.channels"}
          ] do
        assert {:ok, %{view: "bot", viewer: @bot_user}} =
                 Webhook.normalize_signal(trigger, payload!(fixture)),
               fixture
      end
    end

    # Derived: the captured share into the bot DM with the captured
    # authorization of the user's DM without the bot, once in the bot DM and
    # once moved into that DM. All 18 message deliveries captured from the
    # bot DM named the bot, and no share in a DM without the bot was
    # captured.
    test "a share keeps shared_messages and its DM in both views, so the bot DM marks a handover" do
      user_view = payload!("message_im_user_view")

      assert {:ok, %WebhookDelivery{normalized_signal: handover}} =
               replay("message_im_shared_public")

      assert %{
               view: "bot",
               viewer: @bot_user,
               conversation: %{id: @bot_dm},
               shared_messages: [shared]
             } = handover

      for channel <- [@bot_dm, "D0CDPKW29DJ"] do
        capture =
          derive("message_im_shared_public", fn payload ->
            payload
            |> Map.put("authorizations", user_view["authorizations"])
            |> put_in(["event", "channel"], channel)
          end)

        assert {:ok, %WebhookDelivery{normalized_signal: share}} = replay(capture)

        assert %{
                 channel: ^channel,
                 conversation: %{id: ^channel},
                 view: "user",
                 viewer: @authorizing_user,
                 shared_messages: [^shared]
               } = share
      end
    end

    # Derived from the captured user event.
    test "a delivery without a readable authorization has no view" do
      payload = payload!("message_public_user_view")
      [authorization] = payload["authorizations"]

      for authorizations <- [
            nil,
            [],
            "not a list",
            ["not a map"],
            [Map.delete(authorization, "is_bot")],
            [Map.put(authorization, "is_bot", "false")]
          ] do
        assert {:ok, signal} =
                 payload
                 |> Map.put("authorizations", authorizations)
                 |> then(&Webhook.normalize_signal("message.channels", &1))

        refute Map.has_key?(signal, :view)
        refute Map.has_key?(signal, :viewer)
      end

      for user_id <- [nil, ""] do
        assert {:ok, signal} =
                 Webhook.normalize_signal(
                   "message.channels",
                   Map.put(payload, "authorizations", [
                     Map.put(authorization, "user_id", user_id)
                   ])
                 )

        assert signal.view == "user"
        refute Map.has_key?(signal, :viewer)
      end
    end
  end

  describe "change signals" do
    test "captured edits and deletions from conversations with the bot name the bot's view" do
      for {fixture, trigger} <- [
            {"message_changed_public", "message.channels.changed"},
            {"message_changed_im", "message.im.changed"},
            {"message_deleted_mpim", "message.mpim.deleted"},
            {"message_changed_tombstone", "message.channels.deleted"}
          ] do
        assert {:ok, %{view: "bot", viewer: @bot_user}} =
                 Webhook.normalize_signal(trigger, payload!(fixture)),
               fixture
      end
    end

    # The captured link unfurl in the user's DM without the bot is no edit.
    # Derived from it: the same change with a new message.edited.
    test "a change in a DM without the bot carries the user view" do
      assert {:ok, %WebhookDelivery{normalized_signal: nil}} = replay("message_changed_unfurl")

      capture =
        derive("message_changed_unfurl", fn payload ->
          put_in(payload, ["event", "message", "edited"], %{
            "user" => @authorizing_user,
            "ts" => "1793628140.000000"
          })
        end)

      assert {:ok, %WebhookDelivery{normalized_signal: %{} = signal}} = replay(capture)

      assert %{
               subtype: "message_changed",
               channel: "D0CDPKW29DJ",
               ts: "1793628131.336459",
               editor: @authorizing_user,
               view: "user",
               viewer: @authorizing_user
             } = signal
    end
  end

  describe "actions with a lease of each profile" do
    setup {Req.Test, :verify_on_exit!}

    setup do
      Application.put_env(:jido_connect_slack, :slack_req_options, plug: {Req.Test, __MODULE__})

      Application.put_env(:jido_connect_slack, :slack_oauth_req_options,
        plug: {Req.Test, __MODULE__.OAuth}
      )

      on_exit(fn ->
        Application.delete_env(:jido_connect_slack, :slack_req_options)
        Application.delete_env(:jido_connect_slack, :slack_oauth_req_options)
      end)

      Req.Test.stub(__MODULE__.OAuth, fn conn ->
        Req.Test.json(conn, SyntheticFixture.body!("oauth_v2_access_bot_and_user"))
      end)

      assert {:ok, token} =
               OAuth.exchange_code("code",
                 client_id: "client",
                 client_secret: "secret",
                 base_url: "https://slack.test"
               )

      # Slack's example grants other scopes than the history reads need; the
      # host's grant here holds channels:history for both tokens.
      token =
        token
        |> Map.put(:scope, ["channels:history"])
        |> put_in([:authed_user, :scope], ["channels:history"])

      %{token: token}
    end

    # The recordings are the user token's read of #jc-live-no-bot and the
    # bot token's denial of the same channel, from the live smoke tests.
    test "slack.conversation.history sends the user token under a user lease and the bot token under a bot lease",
         %{token: token} do
      input = %{channel: "C0CDDP1JEAX", conversation_type: "public_channel"}

      stub_recording("Bearer xoxp-synthetic-user", "conversation_history_user_view")

      assert {:ok, %{messages: messages, has_more: false}} =
               Connect.invoke(
                 Jido.Connect.Slack,
                 "slack.conversation.history",
                 input,
                 runtime(:user, token)
               )

      assert_received {:slack_request, "/api/conversations.history", "Bearer xoxp-synthetic-user"}

      recorded = LiveSmoke.fixture!(:slack, "conversation_history_user_view")["messages"]

      assert Enum.map(messages, &{&1.ts, &1.user, &1.bot_id}) ==
               Enum.map(recorded, &{&1["ts"], &1["user"], &1["bot_id"]})

      assert Enum.any?(messages, &(&1.user == @authorizing_user and &1.bot_id == nil))
      assert Enum.any?(messages, &(&1.user == @bot_user and &1.bot_id != nil))

      stub_recording("Bearer xoxb-synthetic-bot", "conversation_history_not_in_channel")

      assert {:error, %Error.ProviderError{reason: "not_in_channel"}} =
               Connect.invoke(
                 Jido.Connect.Slack,
                 "slack.conversation.history",
                 input,
                 runtime(:bot, token)
               )

      assert_received {:slack_request, "/api/conversations.history", "Bearer xoxb-synthetic-bot"}
    end

    test "slack.thread.replies sends the token of the lease's profile", %{token: token} do
      input = %{channel: "C0CEEB41FU0", ts: "1793371034.447499", limit: 2}

      for {profile, authorization} <- [
            user: "Bearer xoxp-synthetic-user",
            bot: "Bearer xoxb-synthetic-bot"
          ] do
        stub_recording(authorization, "thread_replies_pages")

        assert {:ok, %{thread_ts: "1793371034.447499"}} =
                 Connect.invoke(
                   Jido.Connect.Slack,
                   "slack.thread.replies",
                   input,
                   runtime(profile, token)
                 )

        assert_received {:slack_request, "/api/conversations.replies", ^authorization}
      end
    end

    defp stub_recording(authorization, fixture) do
      test_pid = self()

      Req.Test.stub(__MODULE__, fn conn ->
        [sent] = Plug.Conn.get_req_header(conn, "authorization")
        send(test_pid, {:slack_request, conn.request_path, sent})

        if sent == authorization,
          do: Req.Test.json(conn, LiveSmoke.fixture!(:slack, fixture)),
          else: conn |> Plug.Conn.put_status(401) |> Req.Test.json(%{ok: false})
      end)
    end

    defp runtime(profile, token) do
      {owner_type, owner_id, lease_fun} =
        case profile do
          :user -> {:user, token.authed_user.id, &OAuth.user_credential_lease/3}
          :bot -> {:tenant, token.team["id"], &OAuth.bot_credential_lease/3}
        end

      connection =
        Connect.Connection.new!(%{
          id: "slack-#{profile}",
          provider: :slack,
          profile: profile,
          tenant_id: "tenant-1",
          owner_type: owner_type,
          owner_id: owner_id,
          status: :connected,
          scopes: ["channels:history"]
        })

      context =
        Connect.Context.new!(%{
          tenant_id: "tenant-1",
          actor: %{id: "user-1", type: :user},
          connection: connection
        })

      assert {:ok, lease} =
               lease_fun.(token, %{tenant_id: "tenant-1"}, connection: connection)

      [context: context, credential_lease: lease]
    end
  end
end
